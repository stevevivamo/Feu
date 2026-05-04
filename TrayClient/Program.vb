Imports System
Imports System.Windows.Forms

Namespace TrayClient
    Friend Module Program
        <STAThread>
        Sub Main()
            Application.EnableVisualStyles()
            Application.SetCompatibleTextRenderingDefault(False)
            Application.Run(New TrayAppContext())
        End Sub
    End Module
End Namespace
