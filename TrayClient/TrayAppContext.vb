Imports System
Imports System.Drawing
Imports System.IO
Imports System.Net.Http
Imports System.Web.Script.Serialization
Imports System.Windows.Forms

Namespace TrayClient
    Public Class TrayAppContext
        Inherits ApplicationContext

        Private ReadOnly _notify As NotifyIcon
        Private ReadOnly _timer As Timer
        Private ReadOnly _menu As ContextMenuStrip
        Private ReadOnly _http As HttpClient
        Private ReadOnly _json As JavaScriptSerializer

        Private ReadOnly _baseUri As String = "http://localhost/state.aspx"

        Public Sub New()
            _json = New JavaScriptSerializer()
            _http = New HttpClient()

            _menu = New ContextMenuStrip()
            _menu.Items.Add("Actualiser", Nothing, AddressOf RefreshNow)
            _menu.Items.Add("Quitter", Nothing, AddressOf QuitApp)

            _notify = New NotifyIcon() With {
                .Visible = True,
                .Text = "Indicateur partagé",
                .ContextMenuStrip = _menu,
                .Icon = BuildIcon(Color.Gray)
            }

            _timer = New Timer() With {.Interval = 5000}
            AddHandler _timer.Tick, AddressOf OnTick
            _timer.Start()

            FetchAndUpdate()
        End Sub

        Private Sub OnTick(sender As Object, e As EventArgs)
            FetchAndUpdate()
        End Sub

        Private Sub RefreshNow(sender As Object, e As EventArgs)
            FetchAndUpdate()
        End Sub

        Private Async Sub FetchAndUpdate()
            Try
                Dim raw = Await _http.GetStringAsync(_baseUri)
                Dim state = _json.Deserialize(Of StateModel)(raw)
                If state Is Nothing Then Return

                Dim c As Color = Color.Gray
                Select Case (If(state.color, "").ToLowerInvariant())
                    Case "red"
                        c = Color.FromArgb(229, 57, 53)
                    Case "green"
                        c = Color.FromArgb(67, 160, 71)
                    Case "yellow"
                        c = Color.FromArgb(251, 192, 45)
                End Select

                Dim icon = BuildIcon(c)
                Dim tooltip = If(String.IsNullOrWhiteSpace(state.message), "(pas de message)", state.message.Trim())
                If tooltip.Length > 63 Then tooltip = tooltip.Substring(0, 63)

                _notify.Icon = icon
                _notify.Text = tooltip
            Catch
                _notify.Icon = BuildIcon(Color.Gray)
                _notify.Text = "Indicateur indisponible"
            End Try
        End Sub

        Private Function BuildIcon(color As Color) As Icon
            Dim bmp As New Bitmap(16, 16)
            Using g = Graphics.FromImage(bmp)
                g.SmoothingMode = Drawing2D.SmoothingMode.AntiAlias
                g.Clear(Color.Transparent)
                Using brush As New SolidBrush(color)
                    g.FillEllipse(brush, 1, 1, 14, 14)
                End Using
                Using pen As New Pen(Color.FromArgb(80, 0, 0, 0), 1)
                    g.DrawEllipse(pen, 1, 1, 14, 14)
                End Using
            End Using

            Dim hIcon = bmp.GetHicon()
            Return Icon.FromHandle(hIcon)
        End Function

        Private Sub QuitApp(sender As Object, e As EventArgs)
            _timer.Stop()
            _notify.Visible = False
            _notify.Dispose()
            _timer.Dispose()
            _http.Dispose()
            _menu.Dispose()
            Application.Exit()
        End Sub

        Private Class StateModel
            Public Property color As String
            Public Property message As String
        End Class
    End Class
End Namespace
