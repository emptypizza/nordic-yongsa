using Godot;

namespace Nordic;

public partial class LogicTests : Node
{
    private int _fail;

    public override void _Ready()
    {
        // StepToward: 대각선 절대 없음(둘 중 한 축만 ±1)
        Check("step-diag-x-major", GridUtil.StepToward(new Vector2I(0, 0), new Vector2I(3, 1)) == new Vector2I(1, 0));
        Check("step-diag-z-major", GridUtil.StepToward(new Vector2I(0, 0), new Vector2I(1, 3)) == new Vector2I(0, 1));
        Check("step-neg", GridUtil.StepToward(new Vector2I(5, 5), new Vector2I(5, 2)) == new Vector2I(0, -1));
        Check("step-same", GridUtil.StepToward(new Vector2I(2, 2), new Vector2I(2, 2)) == Vector2I.Zero);

        // CellToWorld / WorldToCell 왕복
        var w = GridUtil.CellToWorld(3, 7, 0.5f);
        Check("cell2world-x", Mathf.IsEqualApprox(w.X, 3f));
        Check("cell2world-z", Mathf.IsEqualApprox(w.Z, 7f));
        Check("world2cell", GridUtil.WorldToCell(w) == new Vector2I(3, 7));

        // 경계 클램프
        Check("clamp-col", GridUtil.ClampCol(99) == GridUtil.Cols - 1 && GridUtil.ClampCol(-5) == 0);
        Check("clamp-row", GridUtil.ClampRow(99) == GridUtil.Rows - 1 && GridUtil.ClampRow(-5) == 0);

        GD.Print(_fail == 0 ? "[selftest] ALL PASS" : $"[selftest] {_fail} FAIL");
        GetTree().Quit(_fail == 0 ? 0 : 1);
    }

    private void Check(string name, bool ok)
    {
        GD.Print($"[selftest] {name}: {(ok ? "PASS" : "FAIL")}");
        if (!ok) _fail++;
    }
}
