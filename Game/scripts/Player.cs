using Godot;

namespace Nordic;

public partial class Player : Node3D
{
	public int Cx { get; private set; } = GridUtil.Cols / 2 + 1;
	public int Cz { get; private set; } = 0;

	private bool _hopping;
	private int _moveToken;
	private Node3D _model;

	// Godot forward(local -Z)를 이동 방향으로 돌리기 위한 보정각(+180°). 스크린샷으로 튜닝.
	private const float ModelYawOffset = Mathf.Pi;

	public override void _Ready()
	{
		BuildVisual();
		Position = GridUtil.CellToWorld(Cx, Cz, 0f);
	}

	private void BuildVisual()
	{
		_model = GD.Load<PackedScene>("res://scripts/Test Ch.glb").Instantiate<Node3D>();
		_model.Scale = Vector3.One * 0.03f;
		AddChild(_model);

		// Test Ch.glb에 내장된 Idle 애니메이션을 기본 루프 재생
		if (_model.FindChild("AnimationPlayer", true, false) is AnimationPlayer anim)
		{
			Animation clip = anim.GetAnimation("Idle");
			if (clip != null)
				clip.LoopMode = Animation.LoopModeEnum.Linear;
			anim.Play("Idle");
		}
	}

	public override void _Process(double delta)
	{
		if (_hopping) return;

		// 누르고 있으면 hop 완료 후 다음 프레임에 연속 hop (디자인: hold = 연속 hop)
		if (Input.IsActionPressed("move_up")) TryHop(0, 1);
		else if (Input.IsActionPressed("move_down")) TryHop(0, -1);
		else if (Input.IsActionPressed("move_left")) TryHop(1, 0);
		else if (Input.IsActionPressed("move_right")) TryHop(-1, 0);
	}

	public void TryHop(int dx, int dz)
	{
		if (_hopping) return;
		FaceDirection(dx, dz); // 경계에 막혀도 누른 방향은 바라본다
		int nx = GridUtil.ClampCol(Cx + dx);
		int nz = GridUtil.ClampRow(Cz + dz);
		if (nx == Cx && nz == Cz) return; // 경계에 막힘
		Cx = nx;
		Cz = nz;
		_hopping = true;
		int moveToken = ++_moveToken;
		Vector3 target = GridUtil.CellToWorld(Cx, Cz, 0f);
		Tween tween = CreateTween();
		tween.TweenProperty(this, "position", target, 0.12f).SetTrans(Tween.TransitionType.Sine);
		tween.TweenCallback(Callable.From(() =>
		{
			if (moveToken == _moveToken)
				_hopping = false;
		}));
	}

	private void FaceDirection(int dx, int dz)
	{
		// cell delta == 월드 방향(TileSize=1). 이동 방향을 향해 모델 Y축만 회전(Scale 보존).
		float yaw = Mathf.Atan2(dx, dz) + ModelYawOffset;
		_model.Rotation = new Vector3(0f, yaw, 0f);
	}

	public void Knockback(Vector3 awayDir)
	{
		if (awayDir.LengthSquared() < 0.0001f) return;

		Vector3 basePos = GridUtil.CellToWorld(Cx, Cz, 0f);
		Vector3 pushed = basePos + awayDir.Normalized() * GridUtil.TileSize;
		Vector2I cell = GridUtil.WorldToCell(pushed);
		Cx = GridUtil.ClampCol(cell.X);
		Cz = GridUtil.ClampRow(cell.Y);
		_hopping = true;
		int moveToken = ++_moveToken;

		Vector3 target = GridUtil.CellToWorld(Cx, Cz, 0f);
		Tween tween = CreateTween();
		tween.TweenProperty(this, "position", target, 0.15f).SetTrans(Tween.TransitionType.Sine);
		tween.TweenCallback(Callable.From(() =>
		{
			if (moveToken == _moveToken)
				_hopping = false;
		}));
	}
}
