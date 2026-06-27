shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// mokup1.png의 흐르는 파란 강 — GLES3(gl_compatibility) 안전.
// 월드 XZ 좌표로 파동을 계산해 타일 경계 이음새가 없다(MultiMesh 인스턴스별 MODEL_MATRIX).

uniform vec3 deep_color : source_color = vec3(0.09, 0.36, 0.70);
uniform vec3 shallow_color : source_color = vec3(0.22, 0.62, 0.92);
uniform vec3 foam_color : source_color = vec3(0.86, 0.96, 1.0);
uniform vec2 flow = vec2(0.16, 0.05);
uniform float wave_scale = 1.05;
uniform float foam_amount = 0.55;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// 사인 합성 파동(파생함수/노이즈텍스처 불필요 → 모든 백엔드 호환).
float waves(vec2 p, float t) {
	float v = sin((p.x * 1.7 + p.y * 0.9) + t * 1.3);
	v += sin((p.x * 0.9 - p.y * 1.9) - t * 1.1) * 0.7;
	v += sin((p.x * 2.7 + p.y * 2.3) + t * 1.9) * 0.4;
	return v / 2.1;
}

void fragment() {
	vec2 p = world_pos.xz * wave_scale + flow * TIME;
	float w = waves(p, TIME);
	float w2 = waves(p * 1.9 + vec2(3.1, 1.7), TIME * 0.7);
	float m = clamp(0.5 + 0.5 * w, 0.0, 1.0);
	vec3 col = mix(deep_color, shallow_color, m);
	// 파고 마루에 흰 포말선.
	float crest = smoothstep(0.74, 0.97, m * (0.6 + 0.4 * (0.5 + 0.5 * w2)));
	col = mix(col, foam_color, crest * foam_amount);
	ALBEDO = col;
	ROUGHNESS = 0.16;
	SPECULAR = 0.6;
	METALLIC = 0.0;
	EMISSION = shallow_color * crest * 0.22;  // 포말이 은은히 빛나 블룸에 반응
}
