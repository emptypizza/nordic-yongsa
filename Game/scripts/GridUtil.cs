using Godot;

namespace Nordic;

public static class GridUtil
{
    public const float TileSize = 1.0f;
    public const int Cols = 19;  // x: 0..18
    public const int Rows = 30;  // z: 0..29

    public static Vector3 CellToWorld(int cx, int cz, float y = 0f)
        => new Vector3(cx * TileSize, y, cz * TileSize);

    public static Vector2I WorldToCell(Vector3 w)
        => new Vector2I(
            Mathf.RoundToInt(w.X / TileSize),
            Mathf.RoundToInt(w.Z / TileSize));

    public static int ClampCol(int cx) => Mathf.Clamp(cx, 0, Cols - 1);
    public static int ClampRow(int cz) => Mathf.Clamp(cz, 0, Rows - 1);

    public static bool InBounds(int cx, int cz)
        => cx >= 0 && cx < Cols && cz >= 0 && cz < Rows;

    // 직각 한 칸 스텝: 맨해튼 거리를 줄이는 4방향 중, 남은 델타가 큰 축 우선.
    public static Vector2I StepToward(Vector2I from, Vector2I target)
    {
        int dx = target.X - from.X;
        int dz = target.Y - from.Y;
        if (dx == 0 && dz == 0) return Vector2I.Zero;
        if (Mathf.Abs(dx) >= Mathf.Abs(dz))
            return new Vector2I(Mathf.Sign(dx), 0);
        return new Vector2I(0, Mathf.Sign(dz));
    }
}
