using Godot;

namespace Nordic;

public partial class TitleScreen : CanvasLayer
{
    public override void _Ready()
    {
        var bg = new ColorRect
        {
            Color = new Color(0.12f, 0.16f, 0.22f),
        };
        bg.SetAnchorsPreset(Control.LayoutPreset.FullRect);
        AddChild(bg);

        var title = new Label { Text = "GRAIL ESCORT" };
        title.HorizontalAlignment = HorizontalAlignment.Center;
        title.SetAnchorsPreset(Control.LayoutPreset.Center);
        title.CustomMinimumSize = new Vector2(600, 80);
        title.Size = new Vector2(600, 80);
        title.Position = new Vector2(-300, -200);
        AddChild(title);

        var start = new Button { Text = "START" };
        start.CustomMinimumSize = new Vector2(300, 90);
        start.Size = new Vector2(300, 90);
        start.SetAnchorsPreset(Control.LayoutPreset.Center);
        start.Position = new Vector2(-150, -45);
        start.Pressed += () => GetTree().ChangeSceneToFile("res://StageSelect.tscn");
        AddChild(start);
    }
}
