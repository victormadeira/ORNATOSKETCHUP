# Manual de Componentes Dinamicos — Ornato Plugin v0.3.0

> Como criar e nomear componentes no SketchUp para que o sistema Ornato
> reconheca pecas, usinagens, furacao, fita de borda e exporte corretamente
> para producao CNC.

---

## 1. Arquitetura de Grupos e Atributos

O plugin identifica entidades no SketchUp atraves de **dicionarios de atributos**
armazenados nos Groups/ComponentInstances.

### Hierarquia de Entidades

```
Modelo SketchUp
  |
  +-- Group "Balcao Cozinha (600x700x560)"     <-- ornato_modulo
  |     |
  |     +-- Group "Lateral ESQ"                 <-- ornato_peca (tipo: lateral)
  |     +-- Group "Lateral DIR"                 <-- ornato_peca (tipo: lateral)
  |     +-- Group "Base"                        <-- ornato_peca (tipo: base)
  |     +-- Group "Topo"                        <-- ornato_peca (tipo: topo)
  |     +-- Group "Fundo"                       <-- ornato_peca (tipo: fundo)
  |     +-- Group "Porta ESQ"                   <-- ornato_agregado (tipo: porta)
  |     +-- Group "Prateleira 1"                <-- ornato_agregado (tipo: prateleira)
  |
  +-- Group "Armario Alto (800x700x350)"        <-- ornato_modulo
        |
        +-- ...
```

### 5 Dicionarios de Atributos

| Dicionario | Aplicado em | Funcao |
|-----------|------------|--------|
| `ornato_modulo` | Group pai do modulo | Identifica como modulo Ornato (tipo, dimensoes, materiais, fixacao) |
| `ornato_peca` | Sub-group de cada peca | Tipo, dimensoes de corte, material, espessura |
| `ornato_agregado` | Sub-group de porta/gaveta/prateleira/divisoria | Tipo de agregado, abertura, sobreposicao |
| `ornato_vao` | Registrado internamente | Espacos internos para agregados |
| `ornato` | Uso geral | Metadados auxiliares |

### Como o Plugin Identifica Entidades

```ruby
# Verifica se um Group e modulo Ornato:
Utils.modulo_ornato?(entity)
# => verifica se entity tem atributo 'tipo' no dicionario 'ornato_modulo'

# Verifica se e peca:
entity.get_attribute('ornato_peca', 'tipo')
# => retorna 'lateral', 'base', 'porta', etc. ou nil
```

---

## 2. Tipos de Modulo

O atributo `tipo` no dicionario `ornato_modulo` define o tipo do modulo:

| Tipo | Descricao | Uso Tipico |
|------|----------|------------|
| `inferior` | Balcao de piso | Cozinha, banheiro, lavanderia |
| `superior` | Armario alto (fixo na parede) | Cozinha, banheiro |
| `torre` | Modulo piso-ao-teto | Cozinha (despensa), quarto |
| `gaveteiro` | Modulo so com gavetas | Cozinha, escritorio |
| `nicho` | Nicho aberto (sem portas) | Estante, decoracao |
| `prateleira` | Prateleira solta | Qualquer ambiente |
| `bancada` | Tampo/bancada | Cozinha, banheiro, escritorio |
| `estante` | Estante com nichos | Sala, escritorio |
| `painel` | Painel decorativo | Sala, quarto |

### Atributos Obrigatorios do Modulo (ornato_modulo)

| Atributo | Tipo | Padrao | Descricao |
|----------|------|--------|-----------|
| `id` | String | auto-gerado | Identificador unico |
| `nome` | String | 'Modulo' | Nome descritivo |
| `tipo` | String | 'inferior' | Tipo do modulo (ver tabela acima) |
| `ambiente` | String | 'Geral' | Ambiente (Cozinha, Quarto, etc.) |
| `largura` | Float | 600 | Largura externa em mm |
| `altura` | Float | 700 | Altura externa em mm |
| `profundidade` | Float | 560 | Profundidade externa em mm |
| `espessura_corpo` | Float | 15 | Espessura NOMINAL do corpo (mm) |
| `espessura_fundo` | Float | 3 | Espessura NOMINAL do fundo (mm) |
| `tipo_fundo` | String | 'rebaixado' | rebaixado, sobreposto, sem_fundo |
| `rebaixo_fundo` | Float | 8 | Rebaixo do fundo (mm) |
| `montagem` | String | 'laterais_entre' | laterais_entre (Brasil) ou base_topo_entre (Europa) |
| `tipo_base` | String | 'pes_regulaveis' | rodape, pes_regulaveis, direta, suspensa |
| `altura_rodape` | Float | 100 | Altura do rodape/pes (mm) |
| `recuo_rodape` | Float | 50 | Recuo frontal do rodape (mm) |
| `fixacao` | String | 'minifix' | minifix, vb, cavilha, confirmat |
| `material_corpo` | String | 'MDF Branco 15mm' | Material do corpo |
| `material_frente` | String | 'MDF Carvalho 15mm' | Material das frentes |
| `material_fundo` | String | 'HDF Branco 3mm' | Material do fundo |
| `fita_corpo` | String | 'PVC 1mm Branco' | Fita de borda do corpo |
| `fita_frente` | String | 'ABS 2mm Carvalho' | Fita de borda das frentes |

### Montagem Brasil vs Europa

| Tipo | Descricao | Formula Largura Base/Topo |
|------|-----------|--------------------------|
| **Brasil** (`laterais_entre`) | Laterais ficam entre base e topo | `largura_modulo - (2 x espessura_corpo)` |
| **Europa** (`base_topo_entre`) | Base e topo ficam entre laterais | `largura_modulo` (inteira) |

---

## 3. Tipos de Peca e Codigos UPM

Cada sub-grupo dentro de um modulo deve ter o atributo `tipo` no dicionario `ornato_peca`.
O plugin mapeia automaticamente para codigos UpMobb na exportacao.

### Tabela Completa de Pecas

| Tipo (ornato_peca) | Codigo UPM | Orientacao (upmdraw) | Descricao |
|--------------------|-----------|---------------------|-----------|
| `lateral` | CM_LAT_DIR | FTE1x2 | Lateral do modulo (generico) |
| `lateral_esq` | CM_LAT_ESQ | FTD1x2 | Lateral esquerda |
| `lateral_dir` | CM_LAT_DIR | FTE1x2 | Lateral direita |
| `base` | CM_BAS | FTED1x3 | Base do modulo |
| `topo` | CM_BAS | FTED1x3 | Topo do modulo |
| `fundo` | CM_FUN_VER | E2x1 | Fundo vertical |
| `fundo_hor` | CM_FUN_HOR | 2x1 | Fundo horizontal |
| `regua` | CM_REG | FT1x3 | Regua/travessa |
| `regua_pe` | CM_REG | FT1x3 | Regua de pe |
| `prateleira` | CM_PRA | F2x1 | Prateleira |
| `divisoria` | CM_DIV | E2x1 | Divisoria vertical |
| `traseira` | CM_TRG | 2x1 | Traseira/costa |
| `tampo` | CM_BAS | - | Tampo avulso |
| `porta` | CM_POR_LIS | FTED2x1 | Porta lisa |
| `porta_provencal` | CM_POR_LIS | FTED2x1 | Porta provencal |
| `porta_almofadada` | CM_POR_LIS | FTED2x1 | Porta almofadada |
| `porta_vidro` | CM_POR_LIS | FTED2x1 | Porta com vidro |
| `porta_veneziana` | CM_POR_LIS | FTED2x1 | Porta veneziana |
| `frente_gaveta` | CM_FRE_GAV_LIS | FTED2x1 | Frente de gaveta |
| `gaveta_lateral_esq` | CM_LEG | FT2x1 | Lateral esquerda gaveta |
| `gaveta_lateral_dir` | CM_LDG | FT2x1 | Lateral direita gaveta |
| `gaveta_fundo` | CM_FUN_GAV_VER | 2x1 | Fundo de gaveta |
| `gaveta_contra_frente` | CM_CFG | FED1x3 | Contra-frente gaveta |
| `gaveta_chapa` | CM_CHGAV | F1x2 | Chapa de gaveta |
| `chapa_porta_ver` | CM_CHPOR_VER_DIR | F1x2 | Chapa porta vertical |
| `chapa_porta_ver_esq` | CM_CHPOR_VER_ESQ | F1x2 | Chapa porta vertical esquerda |
| `chapa_porta_ver_dir` | CM_CHPOR_VER_DIR | F1x2 | Chapa porta vertical direita |

---

## 4. Atributos de Peca (ornato_peca)

Cada sub-grupo de peca DEVE ter estes atributos no dicionario `ornato_peca`:

| Atributo | Tipo | Obrigatorio | Descricao |
|----------|------|------------|-----------|
| `nome` | String | SIM | Nome descritivo (ex: "Lateral ESQ") |
| `tipo` | String | SIM | Tipo da peca (ver Secao 3) |
| `comprimento` | Float | SIM | Maior dimensao de corte em mm |
| `largura` | Float | SIM | Menor dimensao de corte em mm |
| `espessura` | Float | SIM | Espessura NOMINAL em mm (15, 18, 25...) |
| `material` | String | SIM | Nome do material (ex: "MDF Branco 15mm") |

### Nomenclatura de Nomes de Pecas

O plugin gera nomes automaticamente ao criar modulos. Ao criar manualmente,
siga este padrao para que o sistema reconheca:

| Peca | Nome Recomendado |
|------|-----------------|
| Lateral esquerda | `Lateral ESQ` |
| Lateral direita | `Lateral DIR` |
| Base | `Base` |
| Topo | `Topo` |
| Fundo | `Fundo` |
| Prateleira | `Prateleira 1`, `Prateleira 2`, etc. |
| Divisoria | `Divisoria 1`, etc. |
| Porta | `Porta ESQ`, `Porta DIR` |
| Frente gaveta | `Frente Gaveta 1`, etc. |
| Lateral gaveta | `Lat Gaveta ESQ`, `Lat Gaveta DIR` |
| Traseira gaveta | `Tras Gaveta` |
| Fundo gaveta | `Fundo Gaveta` |

---

## 5. Usinagens Automaticas por Tipo de Peca

O plugin gera automaticamente usinagens CNC baseado no **tipo** da peca.
NAO e necessario definir usinagens manualmente para estas operacoes:

### Lateral (`tipo: lateral`)
- Canal vertical para encaixe do fundo (3.5mm ou 6.5mm, prof 10mm)
- Furos minifix face: 2x Ø15mm x 12.7mm prof (alojamento tambor)
- Furos minifix borda inferior: 2x Ø8mm x 34mm prof (parafuso)
- Furos minifix borda superior: 2x Ø8mm x 34mm prof (parafuso)
- Furos cavilha: 2x Ø8mm x 16mm prof (base e topo)
- Sistema 32mm: linha de furos Ø5mm x 10mm prof a cada 32mm
  - Linha frontal: 37mm da borda frontal
  - Linha traseira: (largura - 37mm) da borda frontal
  - Inicio: espessura + 80mm da base
  - Fim: espessura + 80mm do topo

### Base / Topo (`tipo: base, topo`)
- Canal horizontal para encaixe do fundo
- Furos minifix borda esquerda e direita: Ø8mm x 34mm prof
- Furos cavilha: Ø8mm x 16mm prof

### Porta (`tipo: porta`)
- Canecos de dobradica: Ø35mm x 12mm prof, recuo 22mm da borda
  - 2 canecos: portas ate 900mm
  - 3 canecos: portas 901-1200mm
  - 4 canecos: portas 1201-1600mm
  - 5 canecos: portas > 1600mm
  - Recuo topo/base: 80mm
- Furo para puxador: Ø5mm passante, centralizado na borda oposta

### Frente de Gaveta (`tipo: frente_gaveta`)
- Furo para puxador: Ø5mm passante, centro da peca

### Lateral/Frente/Traseira Gaveta (`tipo: lateral_gaveta, frente_gaveta, traseira_gaveta`)
- Canal horizontal para fundo da gaveta: 8mm da base, prof 8mm

### Divisoria (`tipo: divisoria`)
- Furos minifix borda superior e inferior: Ø8mm x 34mm prof
- Furos cavilha: Ø8mm x 16mm prof

---

## 6. Tipos de Usinagem CNC

Todos os tipos de usinagem reconhecidos pelo sistema:

| Tipo | Simbolo Ruby | Descricao | Ferramenta Tipica |
|------|-------------|-----------|-------------------|
| Canal / Groove | `:canal` | Sulco reto (ex: fundo, vidro) | Fresa 3mm ou 6mm |
| Rebaixo / Rabbet | `:rebaixo` | Rebaixo na borda (fundo sobreposto) | Fresa 6mm |
| Dado / Housing | `:dado` | Encaixe para prateleira fixa | Fresa 6mm, 2 passes |
| Pocket | `:pocket` | Rebaixo retangular (caneco, provencal) | Fresa 8mm / Forstner 35mm |
| Furacao | `:furo` | Furo cilindrico (minifix, cavilha, pin) | Brocas 3-35mm |
| Rasgo | `:rasgo` | Rasgo angulado (veneziana) | Fresa 6mm |
| Fresagem Perfil | `:fresagem_perfil` | Perfil decorativo na borda | Fresas perfil |
| Canal Vidro | `:canal` (porta vidro) | Canal para vidro em portas | Fresa 3mm |
| Fresagem Provencal | `:canal` (frontal) | Quadro provencal/shaker | Fresa 8mm |
| Fresagem Almofadada | `:pocket` (frontal) | Almofada em relevo | Fresa 8mm |
| Fresagem Gola | `:fresagem_perfil` | Puxador embutido J-pull | Fresa 8mm |

### Perfis de Borda Disponiveis

| Codigo | Raio (mm) | Fresa (mm) | Descricao |
|--------|----------|-----------|-----------|
| `arredondado_r2` | 2 | 4 | Arredondado R2mm |
| `arredondado` | 3 | 6 | Arredondado R3mm |
| `arredondado_r6` | 6 | 12 | Arredondado R6mm (1/4") |
| `arredondado_r9` | 9 | 18 | Arredondado R9mm (3/8") |
| `chanfro_2` | 2 | 6 | Chanfro 45 graus 2mm |
| `chanfro_45` | 3 | 6 | Chanfro 45 graus 3mm |
| `chanfro_6` | 6 | 12 | Chanfro 45 graus 6mm |
| `ogee` | 8 | 16 | Ogee classico |
| `meia_cana` | 6 | 12 | Meia-cana (Cove) R6mm |
| `meia_cana_r9` | 9 | 18 | Meia-cana (Cove) R9mm |
| `boleado` | 10 | 20 | Boleado R10mm |
| `reto` | 0 | 0 | Reto (sem perfil) |

---

## 7. Ferramentas CNC (Codigos)

Codigos de ferramenta usados na exportacao JSON (compativel UpMobb):

| Codigo | Tipo | Diametro | Uso |
|--------|------|---------|-----|
| `f_15mm_tambor_min` | Broca | 15mm | Alojamento tambor minifix (face) |
| `f_35mm_dob` | Broca Forstner | 35mm | Caneco dobradica |
| `f_8mm_cavilha` | Broca | 8mm | Cavilha / eixo minifix |
| `f_8mm_eixo_tambor_min` | Broca | 8mm | Eixo tambor minifix (borda) |
| `f_5mm_twister243` | Broca | 5mm | Pin sistema 32mm / puxador |
| `f_3mm` | Broca | 3mm | Placa montagem dobradica |
| `p_3mm` | Fresa | 3mm | Canal fundo 3mm |
| `p_8mm_cavilha` | Fresa | 8mm | Canal fundo 6mm / pocket generico |
| `r_f` | Serra | - | Rasgo fundo (serra vertical) |

---

## 8. Categorias de Operacao CNC (Machining Workers)

No JSON exportado, cada operacao CNC tem uma `category` que define o tipo
de processamento na maquina:

| Categoria | Descricao | Operacoes |
|-----------|----------|-----------|
| `transfer_hole` | Furacao (broca vertical/horizontal) | Minifix face, minifix borda, cavilha, pin 32mm, caneco dobradica |
| `Transfer_vertical_saw_cut` | Corte de serra (rasgo) | Canal de fundo, rasgos |
| `transfer_pocket` | Fresagem/pocket | Caneco dobradica (>10mm prof), canais largos, provencal |

### Exemplo de Worker no JSON

```json
{
  "category": "transfer_hole",
  "tool": "f_15mm_tambor_min",
  "face": "front",
  "x": 37.0,
  "y": 37.0,
  "depth": 12.7,
  "diameter": 15.0
}
```

---

## 9. Orientacao / Desenho (upmdraw)

O codigo `upmdraw` indica a orientacao da peca e quais bordas tem fita.
Letras: F=Frontal, T=Topo, E=Esquerda, D=Direita.
Numeros: dimensao1 x dimensao2.

| Codigo | Significado | Pecas que Usam |
|--------|------------|---------------|
| `FTE1x2` | Frontal+Topo+Esquerda | Lateral DIR |
| `FTD1x2` | Frontal+Topo+Direita | Lateral ESQ |
| `FTED1x3` | 4 lados (Frontal+Topo+Esquerda+Direita) | Base, Topo |
| `FT1x3` | Frontal+Topo | Regua, Regua de pe |
| `F2x1` | Frontal | Prateleira |
| `E2x1` | Esquerda | Divisoria, Fundo |
| `FTED2x1` | 4 lados | Porta, Frente gaveta |
| `FT2x1` | Frontal+Topo | Lateral gaveta ESQ/DIR |
| `2x1` | Sem fita | Fundo horizontal, Fundo gaveta, Traseira |
| `F1x2` | Frontal | Chapa gaveta, Chapa porta |
| `FED1x3` | Frontal+Esquerda+Direita | Contra-frente gaveta |

---

## 10. Fita de Borda

### Formato do Codigo

```
CMBOR{largura}x{espessura_em_decimos}{acabamento}
```

Exemplos:
- `CMBOR22x010BRANCO_TX` = Fita PVC 22mm x 1.0mm Branco TX
- `CMBOR22x020CARVALHO` = Fita ABS 22mm x 2.0mm Carvalho
- `CMBOR22x004BRANCO` = Fita PVC 22mm x 0.4mm Branco (economica)
- `CMBOR35x010BRANCO_TX` = Fita PVC 35mm x 1.0mm (para MDF 18mm)
- `CMBOR45x010BRANCO_TX` = Fita PVC 45mm x 1.0mm (para MDF 25mm)

### 4 Lados da Peca

A fita e aplicada em ate 4 bordas da peca. Na Peca Ruby:
- `fita_frente` (Boolean): borda frontal (comprimento)
- `fita_topo` (Boolean): borda topo (largura)
- `fita_tras` (Boolean): borda traseira (comprimento)
- `fita_base` (Boolean): borda inferior (largura)

Representacao visual: `[frente][topo][tras][base]` = ex: `[X][ ][ ][ ]` = 1C

### Codigos de Acabamento

| Codigo | Descricao | Lados com Fita |
|--------|----------|---------------|
| `1C` | 1 comprimento | Frente |
| `1C+1L` | 1 comprimento + 1 largura | Frente + Topo |
| `1C+2L` | 1 comprimento + 2 larguras | Frente + Topo + Base |
| `2C` | 2 comprimentos | Frente + Tras |
| `2C+1L` | 2 comprimentos + 1 largura | Frente + Tras + Topo |
| `4Lados` | Todos os lados | Frente + Tras + Topo + Base |

### Fitas Disponiveis na Biblioteca

| Nome | Tipo | Espessura | Largura |
|------|------|----------|---------|
| PVC 1mm Branco TX | PVC | 1.0mm | 22mm |
| PVC 1mm Branco Liso | PVC | 1.0mm | 22mm |
| PVC 1mm Carvalho | PVC | 1.0mm | 22mm |
| PVC 1mm Freijo | PVC | 1.0mm | 22mm |
| PVC 1mm Preto TX | PVC | 1.0mm | 22mm |
| PVC 1mm Cinza Urbano | PVC | 1.0mm | 22mm |
| ABS 2mm Branco TX | ABS | 2.0mm | 22mm |
| ABS 2mm Carvalho | ABS | 2.0mm | 22mm |
| ABS 2mm Freijo | ABS | 2.0mm | 22mm |
| ABS 2mm Preto TX | ABS | 2.0mm | 22mm |
| ABS 2mm Cinza Urbano | ABS | 2.0mm | 22mm |
| PVC 0.4mm Branco | PVC | 0.4mm | 22mm |
| PVC 0.4mm Carvalho | PVC | 0.4mm | 22mm |
| PVC 1mm Branco TX 35mm | PVC | 1.0mm | 35mm |
| ABS 2mm Branco TX 35mm | ABS | 2.0mm | 35mm |
| PVC 1mm Branco TX 45mm | PVC | 1.0mm | 45mm |

---

## 11. Materiais

### Espessuras Reais

O MDF tem espessura ligeiramente maior que o nominal.
O sistema usa a espessura REAL para calculos de corte e montagem:

| Nominal (mm) | Real (mm) | Uso |
|-------------|----------|-----|
| 3 | 3.0 | HDF (fundos) |
| 6 | 6.0 | HDF/Compensado (fundos reforcados) |
| 9 | 9.0 | MDF |
| 12 | 12.0 | MDF |
| 15 | 15.5 | MDF (corpo padrao) |
| 18 | 18.5 | MDF (corpo reforco) |
| 20 | 20.5 | MDF |
| 25 | 25.5 | MDF (tampos grossos) |
| Engrossado | 31.0 | 2x MDF 15.5mm colados |

### Chapa Padrao

- Dimensao: **2750 x 1850 mm**
- Refilo (borda desperdicada): **10 mm** por lado

### Materiais Disponiveis na Biblioteca (35+)

**MDF 15mm (10 opcoes):** Branco TX, Branco Liso, Carvalho Hanover, Freijo Puro,
Nogueira Terracota, Preto TX, Cinza Urbano, Grigio, Rovere Marsala, Nude

**MDF 18mm (3 opcoes):** Branco TX, Carvalho Hanover, Freijo Puro

**MDF 25mm:** Branco TX

**MDP 15mm (2):** Branco, Carvalho

**MDP 18mm:** Branco

**HDF (2):** Branco 3mm, Branco 6mm

**Compensado (2):** 3mm, 6mm

**Laca (6):** Branca Fosca, Preta Fosca, Grafite Fosca, Verde Musgo, Azul Marinho, Rosa Nude

**Vidro (4):** Incolor 4mm, Fume 4mm, Bronze 4mm, Preto 4mm

**Espelho (3):** Comum 4mm, Fume 4mm, Bronze 4mm

**Aluminio (3):** Natural, Preto, Champanhe

---

## 12. Furacao Sistema 32mm

O sistema 32mm e a base da marcenaria modular. Define as posicoes dos furos
para prateleiras removiveis nas laterais.

### Parametros

| Parametro | Valor | Descricao |
|-----------|-------|-----------|
| Passo | 32 mm | Distancia entre furos |
| Inicio X | 37 mm | Distancia da borda frontal |
| Diametro | 5.0 mm | Furo para pino de prateleira |
| Profundidade | 10 mm | Profundidade do furo |
| Margem superior | esp + 80 mm | Distancia do topo ate primeiro furo |
| Margem inferior | esp + 80 mm | Distancia da base ate primeiro furo |

### Posicao na Lateral

```
         37mm                   largura - 37mm
          |                          |
          v                          v
    +-----|--------------------------|-----+
    |     o                          o     |  <- margem_sup (esp+80mm)
    |     o                          o     |
    |     o    (cada 32mm)           o     |  <- furos pin 5mm
    |     o                          o     |
    |     o                          o     |
    |     o                          o     |
    |     o                          o     |  <- margem_inf (esp+80mm)
    +--------------------------------------+
     borda                              borda
     frontal                            traseira
```

Duas colunas de furos: uma frontal (37mm) e uma traseira (largura - 37mm).

---

## 13. Furacao de Fixacao

### Minifix

Ferragem de fixacao invisivel. Dois componentes:

| Componente | Face | Diametro | Profundidade | Ferramenta |
|-----------|------|---------|-------------|-----------|
| Tambor (alojamento) | Face interna da peca | 15.0 mm | 12.7 mm | f_15mm_tambor_min |
| Parafuso (eixo) | Borda da peca adjacente | 8.0 mm | 34.0 mm | f_8mm_eixo_tambor_min |

Posicoes padrao: 37mm e 70mm da borda.

### Cavilha

| Parametro | Valor |
|-----------|-------|
| Diametro | 8.0 mm |
| Comprimento da cavilha | 35 mm |
| Profundidade do furo | 16.0 mm (cada lado) |
| Folga | +0.15 mm (furo = 8.15mm) |
| Espacamento | 96 mm (3x 32mm) |
| Distancia minima da borda | 32 mm |

### Confirmat

| Componente | Diametro | Profundidade |
|-----------|---------|-------------|
| Furo na borda (recebe parafuso) | 5.0 mm | 50 mm |
| Furo na face (passante) | 8.0 mm | 10 mm |

### Caneco de Dobradica

| Parametro | Valor |
|-----------|-------|
| Diametro | 35.0 mm |
| Profundidade | 12.0-12.5 mm |
| Recuo da borda | 22.0 mm (centro do furo) |
| Recuo topo/base da porta | 80 mm |
| Ferramenta | f_35mm_dob |

### Quantidade de Dobradicas por Altura da Porta

| Altura Porta | Quantidade |
|-------------|-----------|
| Ate 600 mm | 2 |
| 601-900 mm | 2 |
| 901-1200 mm | 3 |
| 1201-1600 mm | 4 |
| > 1600 mm | 5 |

---

## 14. Contorno 2D (Pecas Organicas)

O Motor de Contorno extrai a geometria 2D de qualquer peca no SketchUp,
permitindo corte CNC de formas nao-retangulares.

### Como Funciona

1. O plugin encontra a maior Face no plano XY do grupo da peca
2. Se a face for um retangulo simples (4 edges retas, sem furos) => retorna `nil`
   (o sistema usa comprimento x largura como fallback)
3. Se tiver curvas, arcos ou furos internos => gera contorno

### Formato do Contorno

```json
{
  "outer": [
    { "type": "line", "x2": 100.0, "y2": 0.0 },
    { "type": "arc", "x2": 110.0, "y2": 10.0, "cx": 100.0, "cy": 10.0, "r": 10.0, "dir": "cw" },
    { "type": "line", "x2": 110.0, "y2": 500.0 },
    { "type": "line", "x2": 0.0, "y2": 500.0 },
    { "type": "line", "x2": 0.0, "y2": 0.0 }
  ],
  "holes": [
    { "type": "circle", "cx": 50.0, "cy": 250.0, "r": 20.0 },
    {
      "type": "polygon",
      "segments": [
        { "type": "line", "x2": 70.0, "y2": 400.0 },
        { "type": "line", "x2": 90.0, "y2": 400.0 },
        { "type": "line", "x2": 90.0, "y2": 420.0 },
        { "type": "line", "x2": 70.0, "y2": 420.0 }
      ]
    }
  ]
}
```

### Tipos de Segmento

| Tipo | Campos | G-code |
|------|--------|--------|
| `line` | x2, y2 | G1 (movimento linear) |
| `arc` | x2, y2, cx, cy, r, dir | G2 (CW) ou G3 (CCW) |

### Tipos de Furo/Recorte Interno

| Tipo | Descricao | G-code |
|------|----------|--------|
| `circle` | Furo circular (passa-fio, etc.) | G2 volta completa |
| `polygon` | Recorte poligonal (qualquer forma) | Sequencia de G1/G2/G3 |

### Para Pecas com Contorno Funcionar

Ao modelar uma peca com forma organica no SketchUp:
1. Desenhe a forma como Face no plano XY (normal Z)
2. Use PushPull para dar espessura
3. Agrupe como sub-grupo dentro do modulo
4. Marque com atributos `ornato_peca`
5. O plugin extraira automaticamente o contorno na exportacao

---

## 15. Fluxo de Exportacao JSON

### Visao Geral

```
SketchUp (modelo 3D)
    |
    v
Plugin Ornato (motor_export.rb)
    |
    +-- Identifica modulos Ornato (ornato_modulo)
    +-- Para cada modulo:
    |     +-- Carrega ModuloInfo do grupo
    |     +-- Lista todas as pecas (ornato_peca)
    |     +-- Calcula fita de borda por peca
    |     +-- Gera furacoes automaticas (motor_furacao)
    |     +-- Gera usinagens automaticas (motor_usinagem)
    |     +-- Extrai contorno 2D se nao-retangular (motor_contorno)
    |
    v
JSON com 3 secoes:
    +-- model_entities: pecas com dimensoes, materiais, fita, sub-entidades
    +-- details_project: cliente, projeto, vendedor
    +-- machining: operacoes CNC por peca (workers)
    |
    v
Exportar para arquivo .json  -ou-  Enviar direto para ERP via API
    |
    v
ERP Ornato (Node.js)
    +-- Importa JSON
    +-- Nesting (otimizacao de corte)
    +-- Gera G-code CNC (G1/G2/G3)
```

### Estrutura do JSON

```json
{
  "model_entities": {
    "0": {
      "upmcode": "CM_BAL",
      "upmdescription": "Balcao Cozinha",
      "upmwidth": "600",
      "upmheight": "700",
      "upmdepth": "560",
      "upmmasterid": 1,
      "entities": {
        "0": {
          "upmpiece": true,
          "upmcode": "CM_LAT_DIR",
          "upmdescription": "Lateral DIR",
          "upmwidth": "15.5",
          "upmheight": "600",
          "upmdepth": "552",
          "upmdraw": "FTE1x2",
          "upmedgeside1": "CMBOR22x010BRANCO_TX",
          "entities": {
            "0": { "upmfeedstockpanel": true, "upmcutlength": "600", "upmcutwidth": "552" },
            "1": { "upmedge": 1, "upmcode": "CMBOR22x010BRANCO_TX" }
          }
        }
      }
    }
  },
  "details_project": {
    "client": "Nome Cliente",
    "project": "Projeto Cozinha",
    "my_code": "01"
  },
  "machining": {
    "persistent_id_1": {
      "code": "persistent_id_1A",
      "name_peace": "Lateral DIR",
      "length": 600,
      "width": 552,
      "thickness": 15.5,
      "borders": ["CMBOR22x010BRANCO_TX", "", "", ""],
      "workers": {
        "0": { "category": "Transfer_vertical_saw_cut", "tool": "r_f", "depth": 4.0 },
        "1": { "category": "transfer_hole", "tool": "f_15mm_tambor_min", "diameter": 15.0 }
      }
    }
  }
}
```

---

## 16. Como Criar um Componente Dinamico Manualmente

### Passo a Passo: Criar um Modulo

1. **Criar Group principal** no SketchUp
2. **Definir atributos do modulo** (via Ruby Console ou script):
```ruby
grupo = Sketchup.active_model.selection.first
grupo.set_attribute('ornato_modulo', 'id', 'orn_custom_001')
grupo.set_attribute('ornato_modulo', 'nome', 'Meu Balcao')
grupo.set_attribute('ornato_modulo', 'tipo', 'inferior')
grupo.set_attribute('ornato_modulo', 'ambiente', 'Cozinha')
grupo.set_attribute('ornato_modulo', 'largura', 600)
grupo.set_attribute('ornato_modulo', 'altura', 700)
grupo.set_attribute('ornato_modulo', 'profundidade', 560)
grupo.set_attribute('ornato_modulo', 'espessura_corpo', 15)
grupo.set_attribute('ornato_modulo', 'espessura_fundo', 3)
grupo.set_attribute('ornato_modulo', 'tipo_fundo', 'rebaixado')
grupo.set_attribute('ornato_modulo', 'rebaixo_fundo', 8)
grupo.set_attribute('ornato_modulo', 'montagem', 'laterais_entre')
grupo.set_attribute('ornato_modulo', 'tipo_base', 'pes_regulaveis')
grupo.set_attribute('ornato_modulo', 'altura_rodape', 100)
grupo.set_attribute('ornato_modulo', 'fixacao', 'minifix')
grupo.set_attribute('ornato_modulo', 'material_corpo', 'MDF Branco TX 15mm')
grupo.set_attribute('ornato_modulo', 'material_frente', 'MDF Carvalho Hanover 15mm')
grupo.set_attribute('ornato_modulo', 'material_fundo', 'HDF Branco 3mm')
grupo.set_attribute('ornato_modulo', 'fita_corpo', 'PVC 1mm Branco TX')
grupo.set_attribute('ornato_modulo', 'fita_frente', 'ABS 2mm Carvalho')
```

3. **Criar sub-grupos para cada peca** dentro do grupo principal

4. **Definir atributos de cada peca**:
```ruby
peca = grupo.entities.grep(Sketchup::Group).find { |g| g.name == 'Lateral ESQ' }
peca.set_attribute('ornato_peca', 'nome', 'Lateral ESQ')
peca.set_attribute('ornato_peca', 'tipo', 'lateral')
peca.set_attribute('ornato_peca', 'comprimento', 600.0)  # altura da lateral
peca.set_attribute('ornato_peca', 'largura', 552.0)      # profundidade
peca.set_attribute('ornato_peca', 'espessura', 15)       # nominal
peca.set_attribute('ornato_peca', 'material', 'MDF Branco TX 15mm')
```

### Metodo Recomendado: Usar o Plugin

Em vez de definir atributos manualmente, use as ferramentas do plugin:

1. **Menu > Ornato > Criar Modulo** — define tipo, dimensoes, materiais
2. **Right-click > Adicionar Agregado** — porta, gaveta, prateleira
3. **Menu > Ornato > Pecas Avulsas** — tampo, painel, prateleira solta
4. **Menu > Ornato > Exportar JSON** — exporta para producao

### Pecas Avulsas (fora de modulos)

Para criar pecas que nao pertencem a nenhum modulo (tampos, paineis decorativos):

1. Selecione um Group/Face no SketchUp
2. Use o menu **Ornato > Pecas Avulsas > [tipo]**
3. O plugin criara a peca com atributos corretos
4. Na exportacao, pecas avulsas aparecem como "modulo virtual" com codigo `CM_AVU`

---

## 17. Agregados (Portas, Gavetas, Prateleiras)

### Dicionario ornato_agregado

| Atributo | Tipo | Descricao |
|----------|------|-----------|
| `tipo` | String | porta, gaveta, prateleira, divisoria |
| `subtipo` | String | abrir, basculante, correr (para portas) |
| `abertura` | String | esquerda, direita |
| `sobreposicao` | String | total, meia, interna |
| `vao_id` | String | ID do vao onde foi inserido |
| `porta_tipo` | String | lisa, provencal, almofadada, vidro, etc. |
| `corredica_tipo` | String | telescopica, oculta, tandembox, roller |

### 9 Tipos de Porta

| Tipo | Usinagem | Material |
|------|----------|---------|
| `lisa` | Nenhuma (so caneco + fita) | MDF |
| `provencal` | Fresagem quadro (Shaker) | MDF |
| `almofadada` | Fresagem almofada relevo | MDF |
| `vidro` | Recorte central + canal vidro | MDF + Vidro 4mm |
| `vidro_inteiro` | Nenhuma | Vidro temperado 6mm |
| `perfil_aluminio` | Nenhuma | Aluminio + Vidro |
| `veneziana` | Rasgos angulados | MDF |
| `ripada` | Montagem ripas | MDF |
| `cego` | Nenhuma (sem abertura) | - |

### 4 Tipos de Corredica

| Tipo | Folga/Lado | Descricao |
|------|-----------|-----------|
| `telescopica` | 12.7 mm | Ball-bearing lateral (Blum 560H, Accuride) |
| `oculta` | 5.0 mm (deducao 42mm) | Undermount (Blum TANDEM) |
| `tandembox` | 5.0 mm (deducao 75mm) | Caixa metalica (Blum TANDEMBOX) |
| `roller` | 12.5 mm | Economica nylon (Grass 6600) |

### Sobreposicao de Porta

| Tipo | Descricao | Formula Largura Porta |
|------|----------|----------------------|
| `total` | Porta cobre toda a lateral | vao + 2*esp - 2*folga |
| `meia` | Porta cobre metade da lateral | vao + esp/2 - 2*folga |
| `interna` | Porta dentro do vao | vao - 2*folga |

---

## 18. Templates

### Categorias Disponiveis

| Categoria | Templates |
|----------|-----------|
| Cozinha | Balcao 3 gavetas, Balcao porta, Aereo 2 portas, Aereo basculante |
| Quarto | Roupeiro 2 portas, Comoda, Criado-mudo, Estante livros |
| Banheiro | Gabinete suspenso, Espelheira |
| Escritorio | Mesa 3 gavetas, Estante, Armario arquivo |
| Sala | Rack TV, Estante nichos |
| Lavanderia | Armario vassoura, Balcao tanque |

### Usar Templates

1. Menu **Ornato > Catalogo de Templates**
2. Selecione categoria e template
3. Clique para inserir no modelo
4. Edite dimensoes/materiais via right-click > Propriedades

### Salvar Template Customizado

1. Selecione um modulo Ornato
2. Right-click > **Salvar como Template**
3. Defina nome e categoria
4. O template fica disponivel no catalogo

---

## 19. API / Integracao ERP

### Envio Direto para ERP

O plugin pode enviar o JSON diretamente para o ERP Ornato sem salvar arquivo:

1. Menu **Ornato > Exportar > Enviar para ERP...**
2. Login com email/senha (JWT token)
3. Preview das pecas e modulos
4. Botao "Enviar"
5. ERP recebe, importa lote, processa nesting e gera G-code

### Configuracao do Servidor

Padrao: `http://localhost:3001`

Para alterar (via Ruby Console):
```ruby
Ornato::Engines::MotorApi.configurar_servidor('http://meu-servidor:3001')
```

---

## 20. Referencia Rapida de Atributos

### Para reconhecer como MODULO Ornato:
```
Dicionario: ornato_modulo
Atributo minimo: tipo (String: inferior, superior, torre, gaveteiro, etc.)
```

### Para reconhecer como PECA:
```
Dicionario: ornato_peca
Atributos minimos: nome, tipo, comprimento, largura, espessura, material
```

### Para reconhecer como AGREGADO:
```
Dicionario: ornato_agregado
Atributos minimos: tipo (porta, gaveta, prateleira, divisoria)
```

### Para gerar USINAGENS automaticas:
```
O tipo da peca define quais usinagens sao geradas.
Basta definir ornato_peca.tipo corretamente.
```

### Para exportar CONTORNO 2D:
```
A peca deve ter geometria real no SketchUp (Face com edges).
O motor_contorno extrai automaticamente da Face principal.
```

---

## Resumo Visual: Hierarquia Completa

```
 MODELO SKETCHUP
   |
   +-- [Group] Modulo Ornato
   |     |   ornato_modulo: tipo, dimensoes, materiais, fixacao
   |     |
   |     +-- [Group] Lateral ESQ
   |     |     ornato_peca: tipo=lateral, comp=600, larg=552, esp=15
   |     |     => AUTO: canal fundo + minifix + cavilha + sistema 32mm
   |     |
   |     +-- [Group] Lateral DIR
   |     |     ornato_peca: tipo=lateral, comp=600, larg=552, esp=15
   |     |
   |     +-- [Group] Base
   |     |     ornato_peca: tipo=base, comp=569, larg=552, esp=15
   |     |     => AUTO: canal fundo + minifix borda
   |     |
   |     +-- [Group] Topo
   |     |     ornato_peca: tipo=topo, comp=569, larg=552, esp=15
   |     |
   |     +-- [Group] Fundo
   |     |     ornato_peca: tipo=fundo, comp=569, larg=600, esp=3
   |     |
   |     +-- [Group] Porta ESQ
   |     |     ornato_peca: tipo=porta, comp=696, larg=296, esp=15
   |     |     ornato_agregado: tipo=porta, abertura=esquerda, sobreposicao=total
   |     |     => AUTO: canecos dobradica + furo puxador
   |     |
   |     +-- [Group] Prateleira 1
   |           ornato_peca: tipo=prateleira, comp=569, larg=532, esp=15
   |           ornato_agregado: tipo=prateleira
   |
   +-- [Group] Outro Modulo...
```

---

*Documentacao gerada para Ornato Plugin v0.3.0 — Marco 2026*
