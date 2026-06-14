using Godot;

namespace Nordic;

public partial class StageSelect : CanvasLayer
{
    public override void _Ready()
    {
        var bg = new ColorRect
        {
            Color = new Color(0.12f, 0.16f, 0.22f),
        };
        bg.SetAnchorsPreset(Control.LayoutPreset.FullRect);
        AddChild(bg);

        var title = new Label { Text = "STAGE SELECT" };
        title.HorizontalAlignment = HorizontalAlignment.Center;
        title.SetAnchorsPreset(Control.LayoutPreset.Center);
        title.CustomMinimumSize = new Vector2(600, 80);
        title.Size = new Vector2(600, 80);
        title.Position = new Vector2(-300, -200);
        AddChild(title);

        var stage = new Button { Text = "STAGE 1" };
        stage.CustomMinimumSize = new Vector2(300, 90);
        stage.Size = new Vector2(300, 90);
        stage.SetAnchorsPreset(Control.LayoutPreset.Center);
        stage.Position = new Vector2(-150, -45);
        stage.Pressed += () => GetTree().ChangeSceneToFile("res://Main.tscn");
        AddChild(stage);
    }
}
