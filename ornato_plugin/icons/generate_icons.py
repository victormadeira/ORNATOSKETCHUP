#!/usr/bin/env python3
"""Gerador de ícones Lucide-style para toolbar do Ornato SketchUp Plugin"""
from PIL import Image, ImageDraw, ImageFont
import os, math

SIZE = 24
BG = (0, 0, 0, 0)  # transparente
ORANGE = (230, 126, 34)      # #e67e22 — cor Ornato
WHITE = (255, 255, 255)
DARK = (52, 73, 94)          # #34495e
LIGHT = (189, 195, 199)      # #bdc3c7

out_dir = os.path.dirname(os.path.abspath(__file__))

def new_icon():
    img = Image.new('RGBA', (SIZE, SIZE), BG)
    draw = ImageDraw.Draw(img)
    return img, draw

def save(img, name):
    path = os.path.join(out_dir, f"{name}.png")
    img.save(path)
    print(f"  OK: {name}.png")

# ═══════════════════════════════════════
# 1. CAIXA — cubo 3D (módulo)
# ═══════════════════════════════════════
def icon_caixa():
    img, d = new_icon()
    # Cubo 3D simplificado
    # Face frontal
    d.rectangle([4, 8, 16, 20], outline=ORANGE, width=2)
    # Face topo (perspectiva)
    d.polygon([(4,8), (8,4), (20,4), (16,8)], outline=ORANGE, width=1)
    # Face lateral
    d.polygon([(16,8), (20,4), (20,16), (16,20)], outline=ORANGE, width=1)
    # Linhas internas
    d.line([(8,4), (8,4)], fill=ORANGE)
    save(img, 'caixa')

# ═══════════════════════════════════════
# 2. TEMPLATE — grid/layout
# ═══════════════════════════════════════
def icon_template():
    img, d = new_icon()
    # Grid 2x2 representando templates
    d.rectangle([3, 3, 11, 11], outline=ORANGE, width=2)
    d.rectangle([13, 3, 21, 11], outline=ORANGE, width=2)
    d.rectangle([3, 13, 11, 21], outline=ORANGE, width=2)
    d.rectangle([13, 13, 21, 21], outline=ORANGE, width=2)
    # Ponto central em um quadrado (selecionado)
    d.ellipse([6, 6, 8, 8], fill=ORANGE)
    save(img, 'template')

# ═══════════════════════════════════════
# 3. PORTA — retângulo com dobradiça
# ═══════════════════════════════════════
def icon_porta():
    img, d = new_icon()
    # Porta retangular
    d.rectangle([6, 3, 18, 21], outline=ORANGE, width=2)
    # Puxador (círculo)
    d.ellipse([14, 10, 16, 14], fill=ORANGE)
    # Dobradiças (linhas à esquerda)
    d.line([(6, 7), (4, 7)], fill=ORANGE, width=2)
    d.line([(6, 17), (4, 17)], fill=ORANGE, width=2)
    save(img, 'porta')

# ═══════════════════════════════════════
# 4. GAVETA — caixa com puxador
# ═══════════════════════════════════════
def icon_gaveta():
    img, d = new_icon()
    # Frente da gaveta
    d.rectangle([3, 5, 21, 19], outline=ORANGE, width=2)
    # Puxador horizontal no centro
    d.line([(8, 12), (16, 12)], fill=ORANGE, width=2)
    # Linhas perspectiva (profundidade)
    d.line([(3, 5), (6, 2)], fill=ORANGE, width=1)
    d.line([(21, 5), (21, 2)], fill=ORANGE, width=1)
    save(img, 'gaveta')

# ═══════════════════════════════════════
# 5. PRATELEIRA — linha horizontal dentro de caixa
# ═══════════════════════════════════════
def icon_prateleira():
    img, d = new_icon()
    # Laterais
    d.line([(4, 3), (4, 21)], fill=ORANGE, width=2)
    d.line([(20, 3), (20, 21)], fill=ORANGE, width=2)
    # Prateleiras
    d.line([(4, 8), (20, 8)], fill=ORANGE, width=2)
    d.line([(4, 14), (20, 14)], fill=ORANGE, width=2)
    # Topo e base
    d.line([(4, 3), (20, 3)], fill=ORANGE, width=1)
    d.line([(4, 21), (20, 21)], fill=ORANGE, width=1)
    save(img, 'prateleira')

# ═══════════════════════════════════════
# 6. DIVISÓRIA — linha vertical dentro de caixa
# ═══════════════════════════════════════
def icon_divisoria():
    img, d = new_icon()
    # Caixa exterior
    d.rectangle([3, 4, 21, 20], outline=ORANGE, width=2)
    # Divisória vertical no meio
    d.line([(12, 4), (12, 20)], fill=ORANGE, width=2)
    save(img, 'divisoria')

# ═══════════════════════════════════════
# 7. PECAS — peças avulsas (retângulo + +)
# ═══════════════════════════════════════
def icon_pecas():
    img, d = new_icon()
    # Peça principal (retângulo inclinado)
    d.rectangle([3, 6, 15, 20], outline=ORANGE, width=2)
    # Símbolo + (adicionar)
    d.line([(18, 2), (18, 10)], fill=ORANGE, width=2)
    d.line([(14, 6), (22, 6)], fill=ORANGE, width=2)
    save(img, 'pecas')

# ═══════════════════════════════════════
# 8. EDITAR — lápis
# ═══════════════════════════════════════
def icon_editar():
    img, d = new_icon()
    # Lápis diagonal
    d.line([(4, 20), (18, 6)], fill=ORANGE, width=2)
    d.line([(18, 6), (20, 4)], fill=ORANGE, width=2)
    # Ponta do lápis
    d.polygon([(4, 20), (3, 21), (6, 20)], fill=ORANGE)
    # Borracha
    d.line([(16, 4), (20, 8)], fill=ORANGE, width=1)
    save(img, 'editar')

# ═══════════════════════════════════════
# 9. TRANSFORMAR — seta curvada + peça
# ═══════════════════════════════════════
def icon_transformar():
    img, d = new_icon()
    # Peça/retângulo fonte
    d.rectangle([3, 12, 10, 20], outline=DARK, width=1, fill=(200, 200, 200, 100))
    # Seta curvada (transformação)
    d.arc([5, 3, 19, 15], 200, 340, fill=ORANGE, width=2)
    # Ponta da seta
    d.polygon([(17, 4), (20, 7), (15, 7)], fill=ORANGE)
    # Peça resultado (com cor)
    d.rectangle([14, 12, 21, 20], outline=ORANGE, width=2)
    save(img, 'transformar')

# ═══════════════════════════════════════
# 10. USINAGEM — broca/fresa
# ═══════════════════════════════════════
def icon_usinagem():
    img, d = new_icon()
    # Peça base (retângulo)
    d.rectangle([2, 14, 22, 22], outline=ORANGE, width=1, fill=(240, 235, 220, 180))
    # Broca/fresa (triângulo + haste)
    d.line([(12, 2), (12, 12)], fill=ORANGE, width=2)
    # Ponta da broca (V)
    d.polygon([(9, 12), (12, 16), (15, 12)], fill=ORANGE, outline=ORANGE)
    # Linhas de corte
    d.line([(8, 14), (8, 14)], fill=(231, 76, 60), width=2)
    d.line([(16, 14), (16, 14)], fill=(231, 76, 60), width=2)
    # Furo resultado
    d.ellipse([9, 16, 15, 20], outline=(231, 76, 60), width=1)
    save(img, 'usinagem')

# ═══════════════════════════════════════
# 11. COTAGEM — régua com setas
# ═══════════════════════════════════════
def icon_cotagem():
    img, d = new_icon()
    # Linhas de extensão
    d.line([(4, 4), (4, 20)], fill=ORANGE, width=1)
    d.line([(20, 4), (20, 20)], fill=ORANGE, width=1)
    # Linha de cota horizontal
    d.line([(4, 12), (20, 12)], fill=ORANGE, width=2)
    # Setas
    d.polygon([(4, 10), (4, 14), (7, 12)], fill=ORANGE)
    d.polygon([(20, 10), (20, 14), (17, 12)], fill=ORANGE)
    # Marcas de medida
    d.line([(12, 10), (12, 14)], fill=ORANGE, width=1)
    save(img, 'cotagem')

# ═══════════════════════════════════════
# 12. FICHA — documento
# ═══════════════════════════════════════
def icon_ficha():
    img, d = new_icon()
    # Folha de papel com canto dobrado
    d.polygon([(5, 2), (15, 2), (19, 6), (19, 22), (5, 22)], outline=ORANGE, width=2)
    # Canto dobrado
    d.polygon([(15, 2), (15, 6), (19, 6)], outline=ORANGE, width=1)
    # Linhas de texto
    d.line([(7, 10), (17, 10)], fill=ORANGE, width=1)
    d.line([(7, 13), (17, 13)], fill=ORANGE, width=1)
    d.line([(7, 16), (14, 16)], fill=ORANGE, width=1)
    d.line([(7, 19), (17, 19)], fill=ORANGE, width=1)
    save(img, 'ficha')

# ═══════════════════════════════════════
# 13. ETIQUETAS — tag/label
# ═══════════════════════════════════════
def icon_etiquetas():
    img, d = new_icon()
    # Tag principal
    d.polygon([(3, 6), (14, 6), (21, 12), (14, 18), (3, 18)], outline=ORANGE, width=2)
    # Furo da tag
    d.ellipse([5, 10, 9, 14], outline=ORANGE, width=1)
    # Segunda tag atrás (offset)
    d.line([(5, 4), (16, 4)], fill=DARK, width=1)
    d.line([(16, 4), (22, 9)], fill=DARK, width=1)
    save(img, 'etiquetas')

# ═══════════════════════════════════════
# 14. EXPORTAR — seta para fora + caixa
# ═══════════════════════════════════════
def icon_exportar():
    img, d = new_icon()
    # Caixa (parte de baixo, aberta em cima)
    d.line([(4, 10), (4, 21)], fill=ORANGE, width=2)
    d.line([(4, 21), (20, 21)], fill=ORANGE, width=2)
    d.line([(20, 10), (20, 21)], fill=ORANGE, width=2)
    # Seta para cima (exportar)
    d.line([(12, 16), (12, 3)], fill=ORANGE, width=2)
    d.polygon([(8, 7), (12, 3), (16, 7)], fill=ORANGE)
    save(img, 'exportar')

# ═══════════════════════════════════════
# 15. VALIDAR — check dentro de escudo
# ═══════════════════════════════════════
def icon_validar():
    img, d = new_icon()
    # Escudo
    d.polygon([(12, 2), (21, 6), (21, 14), (12, 22), (3, 14), (3, 6)], outline=ORANGE, width=2)
    # Check mark
    d.line([(7, 12), (10, 16)], fill=ORANGE, width=2)
    d.line([(10, 16), (17, 8)], fill=ORANGE, width=2)
    save(img, 'validar')

# ═══════════════════════════════════════
# 16. PAINEL — janela lateral
# ═══════════════════════════════════════
def icon_painel():
    img, d = new_icon()
    # Janela principal
    d.rectangle([3, 3, 21, 21], outline=ORANGE, width=2)
    # Barra de título
    d.line([(3, 7), (21, 7)], fill=ORANGE, width=1)
    # Divisão lateral (sidebar)
    d.line([(10, 7), (10, 21)], fill=ORANGE, width=1)
    # Pontos na sidebar
    d.ellipse([5, 10, 7, 12], fill=ORANGE)
    d.ellipse([5, 14, 7, 16], fill=ORANGE)
    d.ellipse([5, 18, 7, 20], fill=ORANGE)
    # Linhas de conteúdo
    d.line([(12, 11), (19, 11)], fill=ORANGE, width=1)
    d.line([(12, 14), (19, 14)], fill=ORANGE, width=1)
    d.line([(12, 17), (16, 17)], fill=ORANGE, width=1)
    save(img, 'painel')

# ═══════════════════════════════════════
# GERAR TODOS
# ═══════════════════════════════════════
print("Gerando icones Ornato (24x24 Lucide-style)...")
icon_caixa()
icon_template()
icon_porta()
icon_gaveta()
icon_prateleira()
icon_divisoria()
icon_pecas()
icon_editar()
icon_transformar()
icon_usinagem()
icon_cotagem()
icon_ficha()
icon_etiquetas()
icon_exportar()
icon_validar()
icon_painel()
print(f"\nTotal: 16 icones em {out_dir}")
