# ☀️ O Dia que o Sol sorriu

> *"Quando o céu não escurece — ele apenas observa."*

Projeto de **terror psicológico 3D** em primeira pessoa desenvolvido na **Godot Engine 4** (GDScript + Forward+).

---

## 🛠️ Tecnologias & Configuração

- **Engine:** Godot Engine 4 (`Forward Plus`)
- **Linguagem:** GDScript
- **Controle de versão:** Git + Git LFS (configurado em `.gitattributes` para modelos 3D, áudio e HDRIs)

---

## 📁 Estrutura do Projeto

```text
O-Dia-que-o-Sol-sorriu/
├── assets/
│   ├── audio/
│   │   ├── ambience/      # Sons ambientais e drones
│   │   ├── music/         # Trilhas e temas
│   │   └── sfx/           # Passos, lanterna, interações
│   ├── materials/         # Materiais reutilizáveis (.tres)
│   ├── models/            # Modelos 3D (.glb, .fbx, .blend)
│   ├── shaders/           # Shaders customizados (.gdshader)
│   └── textures/          # Texturas PBR e UI
├── scenes/
│   ├── main/              # Cena principal de entrada (main.tscn)
│   ├── player/            # Cena do jogador em 1ª pessoa (player.tscn)
│   ├── ui/                # Menus, HUD e overlays
│   └── world/             # Mapas, cenários e props interativos
├── scripts/
│   ├── main/              # Scripts da cena principal
│   ├── player/            # Movimentação, câmera e lanterna
│   └── systems/           # Inventário, eventos, áudio e IA
├── icon.svg
├── project.godot
├── .gitattributes
└── .gitignore
```

---

## 🎮 Controles do Protótipo Inicial

A cena inicial (`scenes/main/main.tscn`) já inclui um ambiente de teste 3D com neblina volumétrica, iluminação solar sombria e um controlador em primeira pessoa:

| Tecla / Entrada | Ação |
| :--- | :--- |
| `W A S D` | Movimentação |
| `Mouse` | Câmera em 1ª pessoa |
| `Shift` | Correr |
| `Espaço` | Pular |
| `F` | Ligar / desligar lanterna |
| `Esc` / Clique | Liberar ou capturar o cursor |

---

## 🚀 Como Abrir Localmente

1. Clone o repositório (com [Git LFS](https://git-lfs.com/) instalado para assets futuros):
   ```bash
   git clone https://github.com/Yenni-Mid/O-Dia-que-o-Sol-sorriu.git
   ```
2. Abra a **Godot Engine 4.3+** e clique em **Import** (Importar).
3. Selecione o arquivo `project.godot` na raiz do projeto.
4. Pressione **F5** para testar a cena inicial.
