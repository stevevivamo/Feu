<%@ WebHandler Language="C#" Class="StateHandler" %>

using System;
using System.IO;
using System.Text;
using System.Web;
using System.Web.Script.Serialization;

public class StateHandler : IHttpHandler
{
    private static readonly object FileLock = new object();
    private static readonly JavaScriptSerializer Json = new JavaScriptSerializer();

    private const string DefaultColor = "red";
    private const string DefaultMessage = "";

    public bool IsReusable { get { return true; } }

    public void ProcessRequest(HttpContext context)
    {
        context.Response.ContentType = "application/json; charset=utf-8";

        if (context.Request.HttpMethod == "GET")
        {
            WriteJson(context, ReadState(context));
            return;
        }

        if (context.Request.HttpMethod == "POST")
        {
            var state = ReadState(context);
            var payload = ReadPayload(context);

            object colorObj;
            if (payload != null && payload.TryGetValue("color", out colorObj))
            {
                var color = Convert.ToString(colorObj);
                if (IsValidColor(color)) state.Color = color;
            }

            object msgObj;
            if (payload != null && payload.TryGetValue("message", out msgObj))
            {
                state.Message = msgObj == null ? string.Empty : Convert.ToString(msgObj);
            }

            SaveState(context, state);
            WriteJson(context, state);
            return;
        }

        context.Response.StatusCode = 405;
        WriteJson(context, new StateModel { Color = "red", Message = "Méthode non autorisée" });
    }

    private static string GetStatePath(HttpContext context)
    {
        return context.Server.MapPath("~/App_Data/state.json");
    }

    private static StateModel ReadState(HttpContext context)
    {
        lock (FileLock)
        {
            var path = GetStatePath(context);
            var dir = Path.GetDirectoryName(path);
            if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);

            if (!File.Exists(path))
            {
                var initial = new StateModel { Color = DefaultColor, Message = DefaultMessage };
                File.WriteAllText(path, Json.Serialize(initial), Encoding.UTF8);
                return initial;
            }

            try
            {
                var raw = File.ReadAllText(path, Encoding.UTF8);
                var model = Json.Deserialize<StateModel>(raw) ?? new StateModel();
                model.Color = IsValidColor(model.Color) ? model.Color : DefaultColor;
                model.Message = model.Message ?? string.Empty;
                return model;
            }
            catch
            {
                var fallback = new StateModel { Color = DefaultColor, Message = DefaultMessage };
                File.WriteAllText(path, Json.Serialize(fallback), Encoding.UTF8);
                return fallback;
            }
        }
    }

    private static void SaveState(HttpContext context, StateModel state)
    {
        lock (FileLock)
        {
            var path = GetStatePath(context);
            File.WriteAllText(path, Json.Serialize(state), Encoding.UTF8);
        }
    }

    private static System.Collections.Generic.Dictionary<string, object> ReadPayload(HttpContext context)
    {
        context.Request.InputStream.Position = 0;
        using (var reader = new StreamReader(context.Request.InputStream, Encoding.UTF8))
        {
            var body = reader.ReadToEnd();
            if (string.IsNullOrWhiteSpace(body)) return null;
            try
            {
                return Json.Deserialize<System.Collections.Generic.Dictionary<string, object>>(body);
            }
            catch
            {
                context.Response.StatusCode = 400;
                return null;
            }
        }
    }

    private static bool IsValidColor(string value)
    {
        return string.Equals(value, "red", StringComparison.OrdinalIgnoreCase)
            || string.Equals(value, "green", StringComparison.OrdinalIgnoreCase)
            || string.Equals(value, "yellow", StringComparison.OrdinalIgnoreCase);
    }

    private static void WriteJson(HttpContext context, StateModel state)
    {
        context.Response.Write(Json.Serialize(state));
    }

    private class StateModel
    {
        public string Color { get; set; }
        public string Message { get; set; }
    }
}
