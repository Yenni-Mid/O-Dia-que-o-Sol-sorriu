# DOCUMENTO DE ARQUITETURA TÉCNICA & GDD: O DIA QUE O SOL SORRIU
**Engine:** Godot 4.x (GDScript 2.0 com Tipagem Estática Estrita)
**Estilo:** Survival Horror Furtivo em 1ª Pessoa | Estética PS1 (Low-Poly / Retro 3D)

---

## 1. CONTEXTO NARRATIVO (RESUMO PARA AMBIENTAÇÃO E UI)
* **O Evento (O Dia do Sorriso):** Uma entidade cósmica distorceu o sol em um sorriso macabro e estático, tingindo o céu de amarelo doentio. O pulso inicial destruiu toda a tecnologia elétrica global.
* **A Epidemia da Verdade:** A luz solar corrompida destrói os filtros mentais humanos; quem se expõe não consegue mentir e confessa seus piores traumas até enlouquecer. Sobreviventes deixaram diários nas sombras chamados **"Ecos"**.
* **As Sombras Vivas:** A radiação deu massa e vida às sombras. Pisar na escuridão sem uma fonte de "fogo humano" (como o lampião a óleo) causa dano letal.
* **Os Lunáticos:** Cultistas enlouquecidos pela luz que usam máscaras de lixo (pratos de papelão/sacos com sorrisos desenhados) e patrulham áreas iluminadas.
* **A Missão:** O jogador é um ex-militar buscando seu filho adolescente (Leo), sequestrado há 9 meses para servir de receptáculo do deus-sol no topo do prédio mais alto da cidade (Altar: *Espelho da Alma Partida*). O jogo abre com uma fita VHS (*found footage*) gravada por Leo na escola no dia do colapso.

---

## 2. ESTRUTURA DE DIRETÓRIOS DO PROJETO (`res://`)
Sempre que criar novos arquivos, respeite rigorosamente esta hierarquia:
* `res://core/` -> Autoloads (Singletons), `GameEvents.gd`, `AudioManager.gd`, `SaveManager.gd`.
* `res://entities/player/` -> `Player.tscn`, `player_controller.gd`, `lantern_system.gd`, `sanity_component.gd`, `interaction_ray.gd`.
* `res://entities/enemies/` -> `lunatic_base.tscn`, `shadow_hazard.tscn`, scripts de FSM (`state_machine.gd`, `patrol_state.gd`, `chase_state.gd`).
* `res://systems/interactables/` -> `echo_note.tscn`, `oil_pickup.tscn`, `echo_data.gd` (Custom Resource).
* `res://ui/` -> `hud.tscn`, `echo_reader_ui.tscn`, `fmv_intro.tscn`.
* `res://shaders/` -> `psx_lit.gdshader`, `psx_post_process.gdshader`, `vhs_overlay.gdshader`.
* `res://levels/` -> `main_game.tscn`, `level_01_streets.tscn`.

---

## 3. CAMADAS DE FÍSICA (PHYSICS LAYERS 3D)
Configure e utilize as seguintes *Collision Layers* e *Masks* no código:
* **Layer 1 (`Environment`):** Chão, paredes, obstáculos que bloqueiam movimento e luz solar.
* **Layer 2 (`Player`):** `CharacterBody3D` do jogador.
* **Layer 3 (`Enemies`):** `CharacterBody3D` dos Lunáticos.
* **Layer 4 (`Interactables`):** Áreas/Corpos de Ecos (diários), portas e refis de óleo.
* **Layer 5 (`LanternLight`):** `Area3D` esférica do lampião (detecta Sombras Vivas e alerta Lunáticos).
* **Layer 6 (`CorruptedShadows`):** `Area3D` das Sombras Vivas no chão.

---

## 4. ARQUITETURA DE NÓS DAS CENAS PRINCIPAIS

### A. Cena Principal de Renderização PSX (`main_game.tscn`)
Para garantir o pixelado autêntico de PS1 (320x240) com UI nítida ou filtrada:
```text
MainGame (Node)
├── SubViewportContainer (Stretch: true, Stretch Shrink: 4 -> resulta em 320x240 numa janela 1280x960)
│   └── SubViewport (Handle Input Locally: true, Snap 2D Transforms/Vertices)
│       └── World3D (Node3D) -> Onde os níveis e o Player são instanciados
│           ├── DirectionalLight3D (Sol Amarelo Doentio - Shadow Enabled: true)
│           └── WorldEnvironment (Fog denso ocre/escuro, Tonemap Linear)
└── CanvasLayer_UI (Layer 2)
    ├── PSXPostProcess (ColorRect com shader de Dithering e Color Banding)
    ├── HUD (Control - Barras discretas ou indicadores diegéticos de Óleo/Sanidade)
    └── EchoReaderUI (Control - Tela de leitura de diários encontrados)
    
    
    
 





Player (CharacterBody3D - Script: player_controller.gd)
├── StandingCollision (CollisionShape3D - Capsule height: 1.8)
├── CrouchingCollision (CollisionShape3D - Capsule height: 1.0, Disabled: true)
├── CeilingCheck (RayCast3D - Target: (0, 1.8, 0) para impedir levantar sob objetos)
├── SunExposureRay (RayCast3D - Script atualiza o target_position na direção oposta ao DirectionalLight3D)
├── HeadPivot (Node3D - Posição Y: 1.6)
│   ├── Camera3D (FOV: 75.0)
│   │   └── InteractionRay (RayCast3D - Target: (0, 0, -2.2), Mask: Layer 4)
│   └── HandPivot (Node3D - Suavização de movimento/sway da mão)
│       └── LanternSystem (Node3D - Script: lantern_system.gd)
│           ├── LanternMesh (MeshInstance3D)
│           ├── OmniLight3D (Color: #ff9d3b, Range: 6.5, Attenuation: 1.5, Shadow: true)
│           └── SafeZoneArea (Area3D - Collision Layer: 5, Mask: 3 e 6)
│               └── CollisionShape3D (SphereShape3D - Radius: 5.5)
├── SanityComponent (Node - Script: sanity_component.gd)
└── HealthComponent (Node - Script: health_component.gd)







## 5. ESPECIFICAÇÃO DOS SISTEMAS CORE (LÓGICA DE CÓDIGO)

### 1. Movimentação e Furtividade (`player_controller.gd`)

- **Estados de Movimento:**
    
    - `CROUCHING`: Velocidade = `1.8 m/s` | `noise_radius` = `1.5m` | `visibility_multiplier` = `0.5`.
        
    - `WALKING`: Velocidade = `3.5 m/s` | `noise_radius` = `5.0m` | `visibility_multiplier` = `1.0`.
        
    - `SPRINTING`: Velocidade = `6.0 m/s` | `noise_radius` = `12.0m` | `visibility_multiplier` = `1.5`.
        
- **Head Bobbing:** Calculado via `sin(time * bob_freq) * bob_amp` proporcional à velocidade horizontal do jogador.
    

### 2. O Lampião a Óleo (`lantern_system.gd`)

- **Variáveis:**
    
    - `@export var max_oil: float = 100.0`
        
    - `var current_oil: float = 100.0`
        
    - `@export var burn_rate: float = 1.2` (unidades por segundo)
        
    - `var is_lit: bool = false`
        
- **Comportamento:**
    
    - Input `toggle_lantern` (Tecla `F` ou Botão Direito): Alterna `is_lit` se `current_oil > 0`.
        
    - Quando `is_lit == true`:
        
        - Drena `current_oil -= burn_rate * delta`.
            
        - `OmniLight3D.visible = true` (aplica leve _flicker_ usando `FastNoiseLite` na `light_energy` entre `1.2` e `1.5`).
            
        - `SafeZoneArea.monitoring = true` (ativa o raio que repele Sombras Vivas).
            
        - Aumenta drasticamente a distância em que os Lunáticos enxergam o jogador (`visibility_bonus = +15.0m`).
            
    - Quando `current_oil <= 0`: Força `is_lit = false`, toca som de chama apagando e emite sinal `GameEvents.lantern_depleted`.
        

### 3. Sistema de Luz Solar, Sombra e Sanidade (`sanity_component.gd`)

O jogo verifica constantemente em qual das **3 Zonas de Iluminação** o jogador está:

1. **Exposto ao Sol (`in_sunlight == true`):**
    
    - **Como detectar:** No `_physics_process`, o `SunExposureRay` aponta da cabeça do jogador na direção inversa do vetor `-directional_light.global_transform.basis.z * 100.0` (Mask: Layer 1). Se `!SunExposureRay.is_colliding()`, o jogador está sob o céu aberto recebendo luz direta do sol sorridente.
        
    - **Efeito:** Drena `sanity` em `-8.0 / seg`. Aplica áudio de sussurros/verdades forçadas e distorção cromática na tela.
        
2. **Na Escuridão Absoluta (`!in_sunlight` e `!lantern.is_lit`):**
    
    - **Efeito:** Drena `sanity` lentamente (`-1.5 / seg`) e deixa o jogador vulnerável às Sombras Vivas (`CorruptedShadows`).
        
3. **Protegido pelo Fogo Humano (`!in_sunlight` e `lantern.is_lit`):**
    
    - **Efeito:** Recupera `sanity` (`+3.0 / seg`) e bloqueia o dano das Sombras Vivas.
        

### 4. Sombras Vivas (`shadow_hazard.gd`)

- Nó `Area3D` posicionado em corredores escuros ou becos (Layer 6, Mask: Layer 2 [Player] e Layer 5 [LanternLight]).
    
- Se o `Player` está dentro da área **E** nenhuma `SafeZoneArea` (Layer 5) está sobreposta/ativa:
    
    - A sombra ataca: reduz a velocidade do jogador em 50% e causa `15.0` de dano por segundo ao `HealthComponent`.
        
- Se a `SafeZoneArea` do lampião entra na área da Sombra Viva:
    
    - A sombra "recua" (reduz a opacidade/escala do shader de tentáculos escuros e desativa o dano enquanto a luz estiver presente).
        

### 5. IA dos Lunáticos - Máquina de Estados (`EnemyFSM`)

Os Lunáticos usam `CharacterBody3D` + `NavigationAgent3D` e operam em 4 estados:

- **`PatrolState`:** Segue _waypoints_ (`Marker3D`) nas ruas ensolaradas.
    
- **`SuspiciousState`:** Ativado se ouvir passos (`distance_to_player < player.noise_radius`) ou vir um vislumbre do jogador na penumbra. Vai até a última posição conhecida e olha ao redor.
    
- **`ChaseState`:** Ativado se o `RayCast3D` de visão do Lunático tiver linha de visão limpa para o jogador (alcance base: `8m` no escuro, mas sobe para `22m` se o jogador estiver com o **Lampião Aceso** ou **Exposto ao Sol**).
    
- **`AttackState`:** Ataque corpo a corpo ao alcançar o jogador.
    
- _Detalhe comportamental:_ Lunáticos evitam entrar em áreas de Sombra Viva se o jogador apagar o lampião, criando oportunidades táticas de fuga no escuro.
  
  
  
  
  
  
  
  
  




class_name EchoData
extends Resource

@export var echo_id: String
@export var author_name: String
@export var date_written: String
@export_multiline var confession_text: String
@export var audio_voiceover: AudioStream






## 6. FLUXO DA ABERTURA FMV (`fmv_intro.tscn`)

- Cena inicial do projeto contém um `VideoStreamPlayer` com o arquivo `res://assets/video/school_vhs_intro.ogv` (gravado na escola com o Sol Sorridente inserido em VFX).
    
- Ao iniciar: `VideoStreamPlayer.play()`.
    
- O sinal `VideoStreamPlayer.finished` (ou tecla de _Skip_) chama um _fade-to-black_, exibe na tela o texto tipográfico retrô **"9 MESES DEPOIS..."** acompanhado do som de um fósforo riscando e acendendo o lampião, e carrega `res://levels/main_game.tscn`.
    

## 7. REGRAS DE CODIFICAÇÃO PARA A IA (ANTIGRAVITY)

1. **Tipagem Estática Obrigatória:** Sempre declare tipos para variáveis, parâmetros e retornos de função (`var speed: float = 3.5`, `func take_damage(amount: float) -> void:`).
    
2. **Event Bus (Desacoplamento):** Comunicação entre Player/Inimigos e a HUD deve passar por um Singleton `GameEvents.gd` usando sinais (`signal sanity_changed(current: float, max_val: float)`, `signal oil_changed(current: float, max_val: float)`, `signal echo_opened(data: EchoData)`).
    
3. **Referências Seguras:** Use `@onready var` ou `@export var` para referenciar nós; evite `get_node()` com caminhos hardcoded longos dentro de loops `_process`.
    
4. **Performance PSX:** Mantenha a lógica de iluminação nos cálculos geométricos (`RayCast3D` e `Area3D`) em vez de usar `SubViewport.get_texture().get_image()` para ler pixels de luz, garantindo 60+ FPS constantes.
   
   
   
   
   


shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled, vertex_lighting;

// Configurações da Textura
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable;
uniform vec4 modulate_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform vec2 uv_offset = vec2(0.0, 0.0);

// Configurações do Efeito PS1
uniform float jitter_intensity : hint_range(0.0, 1.0) = 0.5;
uniform vec2 snap_resolution = vec2(320.0, 240.0);
uniform float affine_amount : hint_range(0.0, 1.0) = 1.0;

// Variáveis passadas do Vertex para o Fragment
varying vec2 v_uv_affine;
varying float v_w;
varying vec2 v_uv_regular;

void vertex() {
	// Aplica escala e offset de UV
	v_uv_regular = UV * uv_scale + uv_offset;
	
	// Transforma o vértice para o espaço de recorte (Clip Space)
	vec4 clip_pos = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	
	// 1. Vertex Snapping (Tremor de polígonos clássico do PS1)
	vec2 grid = snap_resolution * (1.0 - jitter_intensity * 0.5);
	vec4 snapped_pos = clip_pos;
	snapped_pos.xyz = clip_pos.xyz / clip_pos.w;
	snapped_pos.xy = floor(grid * snapped_pos.xy) / grid;
	snapped_pos.xyz *= clip_pos.w;
	
	POSITION = mix(clip_pos, snapped_pos, jitter_intensity);
	
	// 2. Affine Texture Mapping (Distorção de textura sem correção de perspectiva)
	v_w = POSITION.w;
	v_uv_affine = v_uv_regular * v_w;
}

void fragment() {
	// Interpola entre UV normal e UV distorcido do PS1
	vec2 final_uv = mix(v_uv_regular, v_uv_affine / v_w, affine_amount);
	
	vec4 tex_color = texture(albedo_texture, final_uv) * modulate_color * COLOR;
	
	ALBEDO = tex_color.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}





shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform int color_depth : hint_range(1, 8) = 5; // 5 bits por canal = 15-bit color (Padrão PS1)
uniform float dither_strength : hint_range(0.0, 2.0) = 1.0;
uniform vec2 target_resolution = vec2(320.0, 240.0);

// Matriz de Bayer 4x4 para o pontilhado (Dithering)
const mat4 BAYER_MATRIX = mat4(
	vec4(-4.0,  0.0, -3.0,  1.0),
	vec4( 2.0, -2.0,  3.0, -1.0),
	vec4(-3.0,  1.0, -4.0,  0.0),
	vec4( 3.0, -1.0,  2.0, -2.0)
);

void fragment() {
	// Pixeliza a leitura da tela de acordo com a resolução alvo
	vec2 grid_uv = floor(SCREEN_UV * target_resolution) / target_resolution;
	vec3 color = texture(screen_texture, grid_uv).rgb;
	
	// Coordenadas na matriz 4x4
	ivec2 pixel_coord = ivec2(mod(floor(SCREEN_UV * target_resolution), 4.0));
	float dither_value = BAYER_MATRIX[pixel_coord.x][pixel_coord.y];
	
	// Calcula os níveis de cor disponíveis (2^color_depth)
	float levels = pow(2.0, float(color_depth)) - 1.0;
	
	// Aplica o dithering e quantiza as cores (Color Banding)
	color += (dither_value / 16.0) * (1.0 / levels) * dither_strength;
	color = clamp(floor(color * levels + 0.5) / levels, 0.0, 1.0);
	
	COLOR = vec4(color, 1.0);
}