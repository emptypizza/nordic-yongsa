using Godot;

namespace Nordic;

public partial class WindowFit : Node
{
    private const int DesignWidth = 1080;
    private const int DesignHeight = 1920;
    private const int MinWidth = 360;
    private const int MinHeight = 640;
    private const float TargetUsableHeightRatio = 0.9f;
    private const float MaxUsableWidthRatio = 0.95f;
    private const float AspectRatio = (float)DesignWidth / DesignHeight;

    public override void _Ready()
    {
        if (DisplayServer.GetName() == "headless" || OS.HasFeature("mobile"))
        {
            return;
        }

        var screen = DisplayServer.WindowGetCurrentScreen();
        var usable = DisplayServer.ScreenGetUsableRect(screen);
        if (usable.Size.X <= 0 || usable.Size.Y <= 0)
        {
            return;
        }

        var maxWidth = Mathf.Max(1, Mathf.FloorToInt(usable.Size.X * MaxUsableWidthRatio));
        var maxHeight = Mathf.Max(1, Mathf.FloorToInt(usable.Size.Y * TargetUsableHeightRatio));
        var height = maxHeight;
        var width = Mathf.RoundToInt(height * AspectRatio);

        if (width > maxWidth)
        {
            width = maxWidth;
            height = Mathf.RoundToInt(width / AspectRatio);
        }

        if (maxWidth >= MinWidth && maxHeight >= MinHeight && (width < MinWidth || height < MinHeight))
        {
            width = MinWidth;
            height = MinHeight;
        }

        var size = new Vector2I(width, height);
        DisplayServer.WindowSetSize(size);
        DisplayServer.WindowSetPosition(usable.Position + (usable.Size - size) / 2);
    }
}
