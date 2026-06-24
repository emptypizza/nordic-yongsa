using Godot;

namespace Nordic;

public partial class Grail : Node3D
{
	[Signal] public delegate void ReachedGoalEventHandler();
	[Signal] public delegate void DiedEventHandler();
	[Signal] public delegate void HealthChangedEventHandler(int hp, int maxHp);

	public int Cx { get; private set; } = GridUtil.Cols / 2;
	public int Cz => GridUtil.ClampRow(Mathf.RoundToInt(Position.Z / GridUtil.TileSize));
	public int MaxHp { get; private set; } = 5;
	public int Hp { get; private set; }

	private const float ForwardSpeed = GridUtil.TileSize / 1.5f; // 0.667 u/s = 기존 1타일/1.5초 평균과 동일
	private float _invincible;
	private MeshInstance3D _mesh;

	public override void _Ready()
	{
		Hp = MaxHp;
		BuildVisual();
		Position = GridUtil.CellToWorld(Cx, Cz, 0.5f);
		EmitSignal(SignalName.HealthChanged, Hp, MaxHp);
	}

	private void BuildVisual()
	{
		_mesh = new MeshInstance3D
		{
			Mesh = new CylinderMesh { TopRadius = 0.25f, BottomRadius = 0.35f, Height = 0.7f }
		};
		_mesh.MaterialOverride = new StandardMaterial3D
		{
			AlbedoColor = new Color(1f, 0.84f, 0f),
			EmissionEnabled = true,
			Emission = new Color(1f, 0.7f, 0f),
			EmissionEnergyMultiplier = 1.5f
		};
		AddChild(_mesh);
	}

	public override void _Process(double delta)
	{
		float dt = (float)delta;

		// 위아래 bob
		_mesh.Position = new Vector3(0, Mathf.Sin(Time.GetTicksMsec() / 300f) * 0.05f, 0);

		// 무적 깜빡임
		if (_invincible > 0f)
		{
			_invincible -= dt;
			_mesh.Visible = Mathf.PosMod(Time.GetTicksMsec() / 100f, 2f) < 1f;
		}
		else
		{
			_mesh.Visible = true;
		}

		float goalZ = (GridUtil.Rows - 1) * GridUtil.TileSize;
		if (Position.Z >= goalZ)
		{
			EmitSignal(SignalName.ReachedGoal);
			SetProcess(false);
			return;
		}
		Position += new Vector3(0f, 0f, ForwardSpeed * dt);
	}

	public void TakeDamage()
	{
		if (_invincible > 0f) return;
		Hp -= 1;
		_invincible = 1.0f;
		EmitSignal(SignalName.HealthChanged, Hp, MaxHp);
		if (Hp <= 0) EmitSignal(SignalName.Died);
	}
}
