using Godot;
using System;

namespace Nordic;

public partial class Hud : CanvasLayer
{
    public event Action<Vector2I> HopRequested;
    public event Action RetryPressed;

    private ProgressBar _hpBar;
    private Label _hpLabel;
    private Label _stageLabel;
    private Panel _resultPanel;
    private Label _resultLabel;

    public override void _Ready()
    {
        BuildTopBar();
        BuildResultPanel();
        BuildDpad();
    }

    private void BuildTopBar()
    {
        _stageLabel = new Label { Text = "STAGE 1" };
        _stageLabel.Position = new Vector2(16, 12);
        AddChild(_stageLabel);

        _hpLabel = new Label { Text = "5 / 5" };
        _hpLabel.Position = new Vector2(16, 36);
        AddChild(_hpLabel);

        _hpBar = new ProgressBar { MinValue = 0, MaxValue = 5, Value = 5, ShowPercentage = false };
        _hpBar.Position = new Vector2(90, 36);
        _hpBar.CustomMinimumSize = new Vector2(180, 18);
        AddChild(_hpBar);
    }

    private void BuildResultPanel()
    {
        _resultPanel = new Panel { Visible = false };
        _resultPanel.SetAnchorsPreset(Control.LayoutPreset.Center);
        _resultPanel.CustomMinimumSize = new Vector2(320, 160);
        _resultPanel.Position = new Vector2(-160, -80);
        AddChild(_resultPanel);

        _resultLabel = new Label { Text = "" };
        _resultLabel.HorizontalAlignment = HorizontalAlignment.Center;
        _resultLabel.SetAnchorsPreset(Control.LayoutPreset.TopWide);
        _resultLabel.Position = new Vector2(0, 24);
        _resultPanel.AddChild(_resultLabel);

        var retry = new Button { Text = "RETRY" };
        retry.CustomMinimumSize = new Vector2(140, 44);
        retry.Position = new Vector2(90, 90);
        retry.Pressed += () => RetryPressed?.Invoke();
        _resultPanel.AddChild(retry);
    }

    private void BuildDpad()
    {
        // 모바일/마우스용 가상 d-pad (좌하단). 같은 4방향 hop을 발생.
        AddDpadButton("▲", new Vector2(70, -150), new Vector2I(0, 1));
        AddDpadButton("▼", new Vector2(70, -60), new Vector2I(0, -1));
        AddDpadButton("◀", new Vector2(20, -105), new Vector2I(-1, 0));
        AddDpadButton("▶", new Vector2(120, -105), new Vector2I(1, 0));
    }

    private void AddDpadButton(string text, Vector2 offset, Vector2I dir)
    {
        var btn = new Button { Text = text };
        btn.CustomMinimumSize = new Vector2(48, 48);
        btn.SetAnchorsPreset(Control.LayoutPreset.BottomLeft);
        btn.Position = offset;
        btn.Pressed += () => HopRequested?.Invoke(dir);
        AddChild(btn);
    }

    public void SetHealth(int hp, int maxHp)
    {
        _hpBar.MaxValue = maxHp;
        _hpBar.Value = hp;
        _hpLabel.Text = $"{hp} / {maxHp}";
    }

    public void ShowResult(string title, Color color)
    {
        _resultLabel.Text = title;
        _resultLabel.AddThemeColorOverride("font_color", color);
        _resultPanel.Visible = true;
    }
}
