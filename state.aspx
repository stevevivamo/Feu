<%@ Page Language="C#" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="System.Text" %>
<%@ Import Namespace="System.Web" %>
<%@ Import Namespace="System.Web.Script.Serialization" %>
<%@ Import Namespace="System.Collections.Generic" %>
<script runat="server">
    private static readonly object FileLock = new object();
    private static readonly JavaScriptSerializer Json = new JavaScriptSerializer();
    private const string DefaultColor = "red";

    protected void Page_Load(object sender, EventArgs e)
    {
        Response.ContentType = "application/json; charset=utf-8";

        if (Request.HttpMethod == "GET")
        {
            WriteJson(ReadState());
            return;
        }

        if (Request.HttpMethod == "POST")
        {
            var state = ReadState();
            var payload = ReadPayload();

            object colorObj;
            if (payload != null && payload.TryGetValue("color", out colorObj))
            {
                var color = Convert.ToString(colorObj);
                if (IsValidColor(color)) state["color"] = color.ToLowerInvariant();
            }

            object msgObj;
            if (payload != null && payload.TryGetValue("message", out msgObj))
            {
                state["message"] = msgObj == null ? string.Empty : Convert.ToString(msgObj);
            }

            SaveState(state);
            WriteJson(state);
            return;
        }

        Response.StatusCode = 405;
        WriteJson(new Dictionary<string, object> { { "color", DefaultColor }, { "message", "Méthode non autorisée" } });
    }

    private string GetStatePath()
    {
        return Server.MapPath("~/App_Data/state.json");
    }

    private Dictionary<string, object> ReadState()
    {
        lock (FileLock)
        {
            var path = GetStatePath();
            var dir = Path.GetDirectoryName(path);
            if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);

            if (!File.Exists(path))
            {
                var initial = new Dictionary<string, object> { { "color", DefaultColor }, { "message", "" } };
                File.WriteAllText(path, Json.Serialize(initial), Encoding.UTF8);
                return initial;
            }

            try
            {
                var raw = File.ReadAllText(path, Encoding.UTF8);
                var model = Json.Deserialize<Dictionary<string, object>>(raw) ?? new Dictionary<string, object>();

                var color = model.ContainsKey("color") ? Convert.ToString(model["color"]) : DefaultColor;
                var message = model.ContainsKey("message") ? Convert.ToString(model["message"]) : string.Empty;

                if (!IsValidColor(color)) color = DefaultColor;

                return new Dictionary<string, object> { { "color", color.ToLowerInvariant() }, { "message", message ?? string.Empty } };
            }
            catch
            {
                var fallback = new Dictionary<string, object> { { "color", DefaultColor }, { "message", "" } };
                File.WriteAllText(path, Json.Serialize(fallback), Encoding.UTF8);
                return fallback;
            }
        }
    }

    private void SaveState(Dictionary<string, object> state)
    {
        lock (FileLock)
        {
            File.WriteAllText(GetStatePath(), Json.Serialize(state), Encoding.UTF8);
        }
    }

    private Dictionary<string, object> ReadPayload()
    {
        Request.InputStream.Position = 0;
        using (var reader = new StreamReader(Request.InputStream, Encoding.UTF8))
        {
            var body = reader.ReadToEnd();
            if (string.IsNullOrWhiteSpace(body)) return null;
            try
            {
                return Json.Deserialize<Dictionary<string, object>>(body);
            }
            catch
            {
                Response.StatusCode = 400;
                return null;
            }
        }
    }

    private bool IsValidColor(string value)
    {
        return string.Equals(value, "red", StringComparison.OrdinalIgnoreCase)
            || string.Equals(value, "green", StringComparison.OrdinalIgnoreCase)
            || string.Equals(value, "yellow", StringComparison.OrdinalIgnoreCase);
    }

    private void WriteJson(object obj)
    {
        Response.Write(Json.Serialize(obj));
    }
</script>
