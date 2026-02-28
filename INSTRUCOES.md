# ORNATO SKETCHUP PLUGIN — INSTRUCOES COMPLETAS E DOCUMENTACAO

## VERSAO: 0.1.0 | DATA: 2026-02-28

---

## 1. VISAO GERAL

O **Ornato SketchUp Plugin** e um plugin de marcenaria parametrica para SketchUp 2021+, escrito em Ruby, que permite projetar moveis sob medida completos para qualquer ambiente de uma casa. O plugin gera automaticamente carcacas 3D, portas, gavetas, prateleiras, divisorias, furacoes, usinagens CNC, lista de corte, plano de corte otimizado, orcamento e toda a documentacao necessaria para producao.

### Objetivo Principal
Qualquer projetista deve ser capaz de desenvolver um projeto completo de marcenaria (cozinha, quarto, banheiro, escritorio, sala, lavanderia) usando APENAS este plugin, sem necessidade de calculos manuais ou ferramentas externas.

### Stack Tecnologico
- **Linguagem**: Ruby (SketchUp Ruby API)
- **UI**: HtmlDialog (HTML/CSS/JS embutido)
- **Target**: SketchUp 2021+
- **Distribuicao**: Pacote .rbz
- **Idioma UI**: Portugues (BR)
- **Cor da marca**: #e67e22 (laranja Ornato)

### Integracao ERP (futuro)
- Servidor Express porta 3001, React/Vite porta 5173, SQLite, JWT auth
- Endpoints: `/api/auth/login`, `/api/biblioteca`, `/api/orcamentos`, `/api/config`
- Engine de calculo: `calcItemV2` / `precoVendaV2` em `engine.js`

---

## 2. ARQUITETURA DO SISTEMA

### 2.1 Estrutura de Arquivos (31 arquivos)

```
ornato_plugin.rb                     # Loader principal (SketchupExtension)
ornato_plugin/
  main.rb                            # Bootstrap — carrega todos os modulos
  config.rb                          # Constantes, specs CNC, parametros
  utils.rb                           # Funcoes utilitarias (conversao, helpers)

  models/                            # Modelos de dados
    peca.rb                          # Peca de corte (comprimento, largura, fita, area)
    vao.rb                           # Vao interno (recursivo, subdivisivel)
    modulo_info.rb                   # Metadata completa do modulo
    material_info.rb                 # Materiais + Biblioteca (35+ materiais, 16+ fitas)

  engines/                           # Motores de calculo e construcao
    motor_caixa.rb                   # Construcao da carcaca 3D
    motor_agregados.rb               # Portas, gavetas, prateleiras, divisorias
    motor_furacao.rb                 # Mapa de furacao sistema 32mm
    motor_fita_borda.rb              # Regras de fita de borda por visibilidade
    motor_usinagem.rb                # Usinagens CNC (canais, pockets, perfis)
    motor_portas.rb                  # 9 tipos de porta especial
    motor_pecas_avulsas.rb           # Tampos, rodapes, requadros, paineis
    motor_plano_corte.rb             # Otimizacao de corte FFD + esquadrejadeira
    motor_templates.rb               # 20+ templates pre-configurados
    motor_precificacao.rb            # Calculo de custo e preco de venda
    motor_alinhamento.rb             # Snap, alinhamento, distribuicao

  tools/                             # Ferramentas interativas do SketchUp
    caixa_tool.rb                    # Tool para criar modulos (click-to-place)
    agregado_tool.rb                 # Tool para adicionar agregados em vaos
    editor_tool.rb                   # Tool para edicao de modulos existentes
    template_tool.rb                 # Tool para colocar templates
    pecas_avulsas_tool.rb            # Tool para pecas avulsas (7 tipos)

  ui/                                # Paineis HtmlDialog
    painel.rb                        # Painel principal (projeto + exportar)
    propriedades.rb                  # Painel de propriedades do modulo
    catalogo_templates.rb            # Catalogo visual de templates

  toolbar.rb                         # Barra de ferramentas SketchUp (9 botoes)
  menu.rb                            # Menu principal "Ornato" completo
  observers.rb                       # Observers (Model, Selection)
  context_menu.rb                    # Menu de contexto (right-click)
```

### 2.2 Ordem de Carregamento (main.rb)

1. config.rb, utils.rb
2. models/ (peca, vao, modulo_info, material_info)
3. engines/ (caixa, agregados, furacao, fita_borda, usinagem, portas, pecas_avulsas, plano_corte, templates, precificacao, alinhamento)
4. tools/ (caixa_tool, agregado_tool, editor_tool, template_tool, pecas_avulsas_tool)
5. ui/ (painel, propriedades, catalogo_templates)
6. toolbar, menu, observers, context_menu

### 2.3 Dicionarios de Atributos SketchUp

Cada modulo/peca/agregado armazena dados em dicionarios de atributos do SketchUp:

| Dicionario        | Uso                                          |
|-------------------|----------------------------------------------|
| `ornato_modulo`   | Dados do modulo (dimensoes, material, tipo)  |
| `ornato_peca`     | Dados de cada peca de corte                  |
| `ornato_agregado` | Dados de portas, gavetas, prateleiras        |
| `ornato_vao`      | Dados de vaos internos                       |

---

## 3. TIPOS DE MODULO

| Tipo        | Descricao                                | Altura Tipica | Profundidade |
|-------------|------------------------------------------|---------------|--------------|
| `inferior`  | Base de cozinha/banheiro (com rodape)    | 850mm         | 560mm        |
| `superior`  | Aereo de cozinha (suspenso)              | 700mm         | 350mm        |
| `torre`     | Coluna (chao ao teto)                    | 2200mm        | 560mm        |
| `bancada`   | Bancada de trabalho/escritorio           | 750mm         | 600mm        |
| `estante`   | Estante aberta ou fechada                | 1800mm        | 350mm        |
| `gaveteiro` | Modulo so com gavetas                    | 850mm         | 560mm        |
| `painel`    | Painel decorativo / nicho               | variavel      | variavel     |

---

## 4. CONSTRUCAO DA CARCACA (motor_caixa.rb)

### 4.1 Parametros de Construcao

| Parametro          | Padrao  | Opcoes                           |
|--------------------|---------|----------------------------------|
| Espessura corpo    | 15mm    | 15, 18, 25mm                    |
| Espessura fundo    | 3mm     | 3mm (HDF), 6mm (MDF/Compensado) |
| Montagem           | Brasil  | Brasil (lat. entre), Europa (base/topo entre) |
| Tipo fundo         | Rebaixado | Rebaixado (canal), Sobreposto (grampeado), Sem fundo |
| Tipo base          | Pes reg. | Rodape, Pes regulaveis, Direta, Suspensa |
| Fixacao            | Minifix | Minifix, VB, Cavilha, Confirmat  |
| Recuo rodape       | 50mm    | configuravel                     |
| Altura rodape      | 100mm   | configuravel                     |

### 4.2 Montagem Brasil vs Europa

**Brasil (laterais_entre)**: Laterais ficam entre a base e o topo.
- Largura interna = Largura externa - (2 x espessura)
- Altura interna = Altura externa

**Europa (base_topo_entre)**: Base e topo ficam entre as laterais.
- Largura interna = Largura externa
- Altura interna = Altura externa - (2 x espessura)

### 4.3 Pecas Geradas

Para um modulo padrao (montagem Brasil):
1. **2 Laterais**: altura x profundidade x espessura
2. **1 Base**: largura_interna x profundidade x espessura
3. **1 Topo**: largura_interna x profundidade x espessura
4. **1 Fundo**: largura_interna x altura_interna x espessura_fundo
5. **1 Rodape** (se aplicavel): largura_interna x altura_rodape x espessura

### 4.4 Auto-aplicacoes na Construcao

Ao construir um modulo, o motor automaticamente:
- Aplica usinagens (canal de fundo, rebaixos)
- Aplica regras de fita de borda
- Registra tudo nos atributos do grupo SketchUp

---

## 5. AGREGADOS (motor_agregados.rb)

### 5.1 Portas

| Tipo abertura | Descricao                     | Ferragem              |
|---------------|-------------------------------|-----------------------|
| `abrir`       | Porta de abrir (dobradica)   | Dobradica 110/165     |
| `basculante`  | Basculante (pistao gas)       | Pistao gas + dobradica |
| `correr`      | Correr (trilho)               | Trilho + roldana      |

**Sobreposicao de porta:**
- `total`: Porta cobre toda a lateral (padrao)
- `meia`: Porta cobre metade da lateral (para 2 portas lado a lado)
- `interna`: Porta fica dentro do vao (menor que o vao)

**Quantidade de dobradicas por altura:**
| Altura da porta | Quantidade |
|-----------------|------------|
| Ate 600mm       | 2          |
| 601 - 1200mm    | 3          |
| 1201 - 1600mm   | 4          |
| Acima 1600mm    | 5          |

**Recuo do caneco**: 80mm do topo e base da porta.

### 5.2 Gavetas

**4 tipos de corredica suportados:**

| Tipo         | Folga/lado | Montagem  | Extensao | Soft-close |
|--------------|-----------|-----------|----------|------------|
| Telescopica  | 12.7mm    | Lateral   | Total    | Opcional   |
| Oculta       | 5.0mm*    | Inferior  | Total    | Integrado  |
| Tandembox    | 5.0mm*    | Inferior  | Total    | Integrado  |
| Roller       | 12.5mm    | Lateral   | 3/4      | Nenhum     |

*Oculta e Tandembox: deducao interna = 42mm (nao e folga por lado, e total)

**Formula da largura da caixa de gaveta:**
- Telescopica: `vao_interno - (2 x 12.7mm) = vao - 25.4mm`
- Oculta/TANDEM: `vao_interno - 42mm` (largura interna)
- Tandembox: Usa perfil metalico lateral (nao MDF)
- Roller: `vao_interno - (2 x 12.5mm) = vao - 25mm`

**Comprimento da gaveta**: Snap para o comprimento padrao de corredica mais proximo (250-700mm).

**Canal para fundo da gaveta**: 8mm da base, profundidade 8mm.

### 5.3 Prateleiras

- Fixa ou removivel (pinos sistema 32mm)
- Recuo frontal padrao: 20mm
- Espessura: mesma do corpo (15/18/25mm)
- Posicao: definida em mm a partir da base

### 5.4 Divisorias

- Verticais (dividem largura) ou horizontais (dividem altura)
- Criam sub-vaos recursivos
- Espessura: mesma do corpo

---

## 6. TIPOS DE PORTA ESPECIAL (motor_portas.rb)

### 6.1 Lista Completa (9 tipos)

| Tipo              | Descricao                                        | Usinagem CNC               |
|-------------------|--------------------------------------------------|-----------------------------|
| `lisa`            | MDF inteiro, sem fresagem                        | Somente caneco              |
| `provencal`       | Quadro fresado simulando moldura (Shaker)        | Pocket 7mm na face          |
| `almofadada`      | Almofada em relevo (raised panel)                | Faixas fresadas 4mm         |
| `vidro`           | Quadro MDF 70mm + vidro 4mm encaixado            | Canal 5x11mm + caneco       |
| `vidro_inteiro`   | 100% vidro temperado 6mm                         | Nenhuma (vid. temperado)    |
| `perfil_aluminio` | Moldura aluminio + vidro/MDF                     | Nenhuma (perfil cortado)    |
| `veneziana`       | Quadro MDF + ripas inclinadas 20 graus                 | Rasgos 6.5x11mm            |
| `ripada`          | Ripas verticais coladas sobre base               | Nenhuma                     |
| `cego`            | Sem porta (vao aberto)                           | —                           |

### 6.2 Specs Construtivas Reais

**Provencal/Shaker (MDF peca unica):**
- Stile/Rail: 60mm (55-65mm)
- Pocket na face: 7mm profundidade
- Raio canto: 8mm
- Fresa: 8mm diametro, 18.000 RPM, 4.0 m/min avanco

**Vidro (quadro MDF):**
- Quadro: 70mm (60-80mm)
- Canal vidro: 5mm largura x 11mm profundidade
- Vidro: 4mm (incolor, fume, bronze, preto)
- Montantes + travessas + vidro encaixado

**Veneziana (louvered):**
- Angulo ripa: 20 graus (17-25)
- Ripa: 6mm espessura x 30mm largura
- Mortise: 11mm profundidade (7/16")
- Quadro: 55mm
- Espacamento: calculado pela formula `(esp_stile + esp_ripa) / sin(angulo)`

**Perfil Aluminio (Hettich):**
- Larguras: 3mm (slim), 8mm (standard), 19mm (wide)
- Vidro aceito: 4, 5, 6mm
- Acabamentos: Natural, Preto, Creme, Cinza
- Montagem: perfis cortados + conectores de canto

**Almofadada (raised panel MDF):**
- Stile: 60mm (55-70mm)
- Canal painel: 6mm x 11mm
- Lingua painel: 6mm

---

## 7. SISTEMA 32MM E FURACAO (motor_furacao.rb)

### 7.1 Regras do Sistema 32mm

| Parametro         | Valor    | Descricao                          |
|-------------------|----------|-------------------------------------|
| Passo             | 32mm     | Distancia entre furos consecutivos |
| Inicio            | 37mm     | Primeiro furo a partir da borda    |
| Recuo borda       | 9.5mm    | Centro do furo na espessura 15mm   |

### 7.2 Tipos de Furacao

| Tipo            | Diametro | Prof.  | Uso                              |
|-----------------|----------|--------|----------------------------------|
| Minifix face    | 15.0mm   | 12.7mm | Alojamento do minifix            |
| Minifix borda   | 8.0mm    | 34.0mm | Parafuso do minifix              |
| Cavilha          | 8.0mm    | 16.0mm | Juncao lateral                   |
| Caneco          | 35.0mm   | 12.5mm | Dobradica (Blum standard)        |
| Pin prateleira  | 5.0mm    | 10.0mm | Suporte de prateleira            |
| Puxador         | 5.0mm    | passante | Fixacao de puxador             |
| Confirmat face  | 8.0mm    | 10.0mm | Parafuso face                    |
| Confirmat borda | 5.0mm    | 50.0mm | Parafuso borda                   |

### 7.3 Caneco de Dobradica (Blum)

| Parametro       | Valor    |
|-----------------|----------|
| Diametro        | 35.0mm   |
| Profundidade    | 12.5mm   |
| Recuo da borda  | 23.0mm   |
| Placa montagem  | 37.0mm   |
| Recuo topo/base | 80.0mm   |

### 7.4 Validacao de Colisao

O motor valida automaticamente:
- Furos que colidem (distancia < soma dos raios)
- Furos muito proximos (distancia < raio + 3mm = aviso)
- Canais que se sobrepoem
- Furos dentro de canais
- Furos muito perto da borda (minimo 3mm)

---

## 8. USINAGENS CNC (motor_usinagem.rb)

### 8.1 Operacoes Disponiveis

| Operacao              | Descricao                                     |
|-----------------------|-----------------------------------------------|
| `canal`               | Canal/groove (para fundo, vidro, painel)      |
| `rebaixo`             | Rabbet (para fundo sobreposto)                |
| `dado`                | Housing/dado (encaixe prateleira/divisoria)   |
| `pocket`              | Pocket (caneco, almofadada, provencal)        |
| `furo`                | Furacao (minifix, cavilha, confirmat, pin)    |
| `rasgo`               | Rasgo inclinado (veneziana)                   |
| `fresagem_perfil`     | Fresagem de borda (arredondado, chanfro, ogee) |
| `fresagem_gola`       | J-pull / puxador embutido                     |

### 8.2 Parametros CNC Reais

| Operacao        | Fresa (mm) | RPM    | Avanco (m/min) | Prof/passe |
|-----------------|-----------|--------|----------------|------------|
| Corte painel    | 6 (compr.) | 18.000 | 7.0            | Total      |
| Canal 3mm       | 3 (reta)   | 18.000 | 4.0            | 5.0mm      |
| Canal 6mm       | 6 (reta)   | 18.000 | 5.0            | 5.0mm      |
| Dado 15mm       | 6 (reta)   | 18.000 | 3.5            | 4.0mm (2x) |
| Dado 18mm       | 6 (reta)   | 18.000 | 3.5            | 5.0mm (2x) |
| Pocket          | 8 (reta)   | 18.000 | 4.0            | 3.5mm      |
| Caneco 35mm     | 35 (Forstner) | 4.000 | Plunge      | Total      |
| Perfil borda    | variavel   | 17.000 | 3.0            | Total      |

### 8.3 Canal para Fundo

| Fundo    | Largura canal | Prof. canal | Dist. borda tras |
|----------|--------------|-------------|-------------------|
| HDF 3mm  | 3.5mm        | 10.0mm      | 7.0mm            |
| MDF 6mm  | 6.5mm        | 10.0mm      | 7.0mm            |

### 8.4 Perfis de Borda Disponiveis

| Perfil        | Raio | Fresa (mm) | Descricao                |
|---------------|------|-----------|---------------------------|
| arredondado_r2| 2mm  | 4mm       | Arredondado R2mm          |
| arredondado   | 3mm  | 6mm       | Arredondado R3mm          |
| arredondado_r6| 6mm  | 12mm      | Arredondado R6mm (1/4")   |
| arredondado_r9| 9mm  | 18mm      | Arredondado R9mm (3/8")   |
| chanfro_2     | 2mm  | 6mm       | Chanfro 45 graus 2mm            |
| chanfro_45    | 3mm  | 6mm       | Chanfro 45 graus 3mm            |
| chanfro_6     | 6mm  | 12mm      | Chanfro 45 graus 6mm            |
| ogee          | 8mm  | 16mm      | Ogee classico             |
| meia_cana     | 6mm  | 12mm      | Meia-cana (Cove) R6mm     |
| meia_cana_r9  | 9mm  | 18mm      | Meia-cana (Cove) R9mm     |
| boleado       | 10mm | 20mm      | Boleado R10mm             |
| reto          | 0    | 0         | Sem perfil                |

### 8.5 Cavilha / Dowel (juncao de paineis)

| Tamanho | Diametro | Comprimento | Prof. furo | Espacamento |
|---------|----------|-------------|------------|-------------|
| Leve    | 6mm      | 30mm        | 17mm       | 96-128mm    |
| Padrao  | 8mm      | 35mm        | 19mm       | 96-128mm    |
| Pesado  | 10mm     | 40mm        | 22mm       | 96-128mm    |

Regras: diametro = 1/3 da espessura do painel. Folga do furo: +0.15mm. Distancia minima da borda: 32mm.

---

## 9. FITA DE BORDA (motor_fita_borda.rb)

### 9.1 Espessuras Disponiveis

| Tipo      | Espessura | Impacto dimensao | Aplicacao                |
|-----------|-----------|-------------------|--------------------------|
| Nenhuma   | 0mm       | 0mm               | Bordas ocultas/internas  |
| Melamine  | 0.4mm     | 0mm               | Bordas internas visiveis |
| Padrao    | 1.0mm     | 1.0mm/lado        | Bordas externas padrao   |
| Premium   | 2.0mm     | 2.0mm/lado        | Alto trafego (tampos)    |
| Pesada    | 3.0mm     | 3.0mm/lado        | Decorativa               |

### 9.2 Regras por Tipo de Peca

| Peca              | Frente   | Topo     | Tras     | Base     |
|-------------------|----------|----------|----------|----------|
| Lateral           | 1mm      | 0.4mm    | —        | —        |
| Base/Topo         | 1mm      | —        | —        | —        |
| Fundo             | —        | —        | —        | —        |
| Prateleira fixa   | 1mm      | —        | —        | —        |
| Prateleira ajust. | 1mm      | 0.4mm    | 1mm      | 0.4mm    |
| Divisoria         | 1mm      | —        | —        | —        |
| Porta             | 1mm      | 1mm      | 1mm      | 1mm      |
| Frente gaveta     | 1mm      | 1mm      | 1mm      | 1mm      |
| Lateral gaveta    | —        | 0.4mm    | —        | —        |
| Traseira gaveta   | —        | 0.4mm    | —        | —        |
| Fundo gaveta      | —        | —        | —        | —        |
| Painel            | 1mm      | 1mm      | 1mm      | 1mm      |
| Tampo             | 2mm      | 1mm      | —        | —        |
| Rodape            | 1mm      | 1mm      | —        | —        |

### 9.3 Ajuste de Dimensao de Corte

Para fitas >= 1mm, o painel deve ser cortado menor:
- Exemplo: peca final 500mm com fita 2mm nos 2 lados compridos -> cortar 496mm
- O motor calcula automaticamente os descontos

### 9.4 Lista de Compras

O sistema calcula:
- Total de metros por material e espessura
- Quantidade de rolos necessarios (50m e 100m)
- Sobra estimada

---

## 10. MATERIAIS (material_info.rb)

### 10.1 Biblioteca de Chapas (35+ materiais)

**MDF 15mm** (10 padroes): Branco TX, Branco Liso, Carvalho Hanover, Freijo Puro, Nogueira Terracota, Preto TX, Cinza Urbano, Grigio, Rovere Marsala, Nude

**MDF 18mm** (3 padroes): Branco TX, Carvalho Hanover, Freijo Puro

**MDF 25mm** (1): Branco TX

**MDP 15mm** (2): Branco, Carvalho | **MDP 18mm** (1): Branco

**HDF** (2): Branco 3mm, Branco 6mm (para fundos)

**Compensado** (2): 3mm, 6mm (fundos refor cados)

**Laca** (6): Branca Fosca, Preta Fosca, Grafite, Verde Musgo, Azul Marinho, Rosa Nude

**Vidro** (4): Incolor 4mm, Fume 4mm, Bronze 4mm, Preto 4mm

**Espelho** (3): Comum 4mm, Fume 4mm, Bronze 4mm

**Aluminio** (3): Natural, Preto, Champanhe

### 10.2 Biblioteca de Fitas (16+ opcoes)

- PVC 1mm: Branco TX, Branco Liso, Carvalho, Freijo, Preto TX, Cinza Urbano (22mm larg.)
- ABS 2mm: Branco TX, Carvalho, Freijo, Preto TX, Cinza Urbano (22mm larg.)
- PVC 0.4mm: Branco, Carvalho (22mm larg.)
- Fitas para 18mm (35mm larg.): PVC 1mm, ABS 2mm
- Fita para 25mm (45mm larg.): PVC 1mm

---

## 11. CORREDICAS — SPECS DETALHADOS

### 11.1 Telescopica (Blum 560H/566H, Hettich, Accuride)

- Folga por lado: 12.7mm
- Montagem: lateral
- Extensao: total (full extension)
- Comprimentos: 250, 300, 350, 400, 450, 500, 550, 600, 650, 700mm
- Capacidade: 30, 45, 60 kg
- Soft-close: opcional (add-on)
- Formula: `largura_gaveta = vao - 25.4mm`

### 11.2 Oculta / TANDEM (Blum 560H/563H/566H/569H)

- Folga real: 5.0mm por lado
- Deducao interna: 42mm total
- Montagem: inferior (embaixo da gaveta)
- Folga inferior: 14mm | Folga superior: 7mm
- Comprimentos: 250, 270, 300, 350, 400, 450, 500, 550, 600mm
- Capacidade: 30-65 kg (conforme modelo)
- Soft-close: Blumotion integrado
- Fundo minimo: 12mm (estrutural)
- Formula: `largura_interna = vao - 42mm`

### 11.3 Tandembox (Blum TANDEMBOX Antaro/Intivo)

- Folga real: 5.0mm por lado
- Deducao base: 75mm
- Perfil lateral: 16.5mm (metalico, substitui lateral MDF)
- Alturas perfil: N(68mm), M(83mm), K(115mm), D(203mm)
- Comprimentos: 270, 300, 350, 400, 450, 500, 550, 600, 650mm
- Capacidade: 30, 65 kg
- Largura modulo: 300-1200mm

### 11.4 Roller (Grass 6600, FGV)

- Folga por lado: 12.5mm
- Montagem: lateral
- Extensao: parcial (3/4)
- Comprimentos: 250, 300, 350, 400, 450, 500, 550, 600mm
- Capacidade: 34 kg
- Soft-close: nenhum (auto-fechamento por gravidade)

---

## 12. PECAS AVULSAS (motor_pecas_avulsas.rb)

| Tipo               | Descricao                              | Opcoes especiais            |
|--------------------|----------------------------------------|-----------------------------|
| `tampo`            | Tampo superior/bancada                 | Recortes para cuba/cooktop  |
| `rodape`           | Rodape frontal/lateral                 | Recuo configuravel          |
| `requadro`         | Requadro de acabamento                 | Acabamento lateral          |
| `painel_lateral`   | Painel lateral de acabamento           | Altura total                |
| `painel_cavilhado` | Painel ripado unido com cavilhas       | Furos de cavilha automaticos|
| `moldura`          | Moldura decorativa                     | Perfil de fresagem          |
| `canaleta_led`     | Canaleta para fita LED                 | Perfil + difusor            |

---

## 13. PLANO DE CORTE (motor_plano_corte.rb)

### 13.1 Chapas Padrao

O motor usa chapas padrao brasileiras:
- MDF/MDP: 2750 x 1850mm (ou 2750 x 1830mm)
- HDF: 2750 x 1850mm
- Compensado: 2200 x 1600mm

### 13.2 Algoritmo de Otimizacao

**First Fit Decreasing Height (FFDH) — Shelf Algorithm:**
1. Ordena pecas por altura decrescente
2. Cria "prateleiras" horizontais na chapa
3. Encaixa pecas na primeira prateleira que cabe
4. Cria nova prateleira quando nenhuma existente comporta a peca

### 13.3 Sequenciamento Esquadrejadeira

O motor gera a sequencia de cortes para esquadrejadeira:
1. **Cortes longitudinais** primeiro (ao longo da chapa, 2750mm)
2. **Cortes transversais** depois (nas faixas resultantes)
3. Cada corte registra: posicao, direcao, peca resultante

### 13.4 Formatos de Exportacao

| Formato            | Descricao                               |
|--------------------|-----------------------------------------|
| CSV                | Lista de corte simples (peca, dimensoes)|
| CSV otimizado      | Plano de corte com posicoes na chapa    |
| TXT esquadrejadeira| Sequencia de cortes passo a passo       |
| XML OpenCutList    | Compativel com plugin OpenCutList       |
| TXT Corte Certo    | Compativel com software Corte Certo     |

---

## 14. TEMPLATES (motor_templates.rb)

### 14.1 Catalogo Pre-configurado (20+ templates)

**Cozinha:**
- Superior 1 Porta, 2 Portas, Basculante, Escorredor
- Inferior 1 Porta, 2 Portas, Forno, Pia, Lixeira
- Gaveteiro 3 Gavetas, 4 Gavetas
- Torre Forno/Micro, Despenseiro

**Quarto:**
- Guarda-roupa 2 Portas, 3 Portas
- Comoda 4 Gavetas
- Criado-mudo

**Banheiro:**
- Gabinete 1 Porta, 2 Portas
- Espelheira

**Escritorio:**
- Mesa com gavetas
- Estante aberta

**Sala:**
- Painel TV
- Estante nichos

**Lavanderia:**
- Armario tanque

### 14.2 Templates Customizados

O usuario pode:
- Salvar qualquer modulo como template (menu ou right-click)
- Templates salvos em disco como arquivos Ruby serializados
- Carregados automaticamente ao iniciar o plugin

---

## 15. PRECIFICACAO (motor_precificacao.rb)

### 15.1 Componentes do Custo

| Componente | Descricao                              |
|------------|----------------------------------------|
| Material   | Chapas MDF/MDP/HDF (R$/m2)            |
| Fita       | Fita de borda PVC/ABS (R$/metro)      |
| Ferragens  | Dobradicas, corredicas, puxadores (un) |
| Usinagem   | Operacoes CNC (por operacao)           |
| Mao obra   | Montagem e acabamento (por modulo)     |

### 15.2 Margem Padrao

- Margem padrao: **35%** sobre o custo total
- Formula: `preco_venda = custo_total x (1 + margem/100)`

### 15.3 Saidas

- Orcamento por modulo (custo e venda)
- Orcamento por ambiente (todos modulos de um comodo)
- Orcamento completo do projeto
- Exportacao CSV para planilha

---

## 16. ALINHAMENTO E SNAP (motor_alinhamento.rb)

| Funcao              | Descricao                              |
|---------------------|----------------------------------------|
| Alinhar horizontal  | Posiciona modulos lado a lado (eixo X) |
| Alinhar profundidade| Alinha modulos no eixo Y               |
| Alinhar altura      | Alinha modulos no eixo Z               |
| Empilhar vertical   | Empilha modulos (torre superior+inferior) |
| Distribuir horizontal| Distribui com espacamento uniforme    |
| Espelhar            | Espelha modulo no eixo X               |
| Snap point          | Ponto de encaixe mais proximo (tol 50mm) |
| Adjacentes?         | Detecta se dois modulos sao adjacentes |

---

## 17. INTERFACE DO USUARIO

### 17.1 Toolbar (9 botoes)

1. **Caixa** (laranja) — Criar modulo
2. **Templates** (verde) — Catalogo de templates
3. *separador*
4. **Porta** — Adicionar porta
5. **Gaveta** — Adicionar gaveta
6. **Prateleira** — Adicionar prateleira
7. **Divisoria** — Adicionar divisoria
8. *separador*
9. **Pecas Avulsas** (roxo) — Menu de pecas avulsas
10. **Editar** — Editor de modulo
11. *separador*
12. **Painel** — Abre painel principal

### 17.2 Menu Principal "Ornato"

```
Ornato
  +- Criar Modulo
  +- Templates >
  |    +- Cozinha > (Superior 1P, 2P, Basculante, Inf 1P, 2P, ...)
  |    +- Quarto > (Guarda-roupa 2P, 3P, Comoda, ...)
  |    +- Banheiro > (Gabinete 1P, 2P, Espelheira)
  |    +- Escritorio > (Mesa gavetas, Estante)
  |    +- Sala > (Painel TV, Estante nichos)
  |    +- Lavanderia > (Armario tanque)
  +- Agregados >
  |    +- Porta
  |    +- Porta Dupla
  |    +- Gaveta
  |    +- Prateleira
  |    +- Divisoria
  +- Portas Especiais >
  |    +- Lisa, Provencal, Almofadada, Vidro, Vidro Inteiro,
  |    +- Perfil Aluminio, Veneziana, Ripada
  +- Pecas Avulsas >
  |    +- Tampo, Rodape, Requadro, Painel Lateral,
  |    +- Painel Cavilhado, Moldura, Canaleta LED
  +- Alinhar/Distribuir >
  |    +- Horizontal, Profundidade, Altura, Empilhar,
  |    +- Distribuir 0mm, Distribuir 3mm, Espelhar
  +- Exportar >
  |    +- Lista Corte CSV
  |    +- Plano Corte Otimizado
  |    +- Sequencia Esquadrejadeira
  |    +- Mapa Furacao
  |    +- Lista Ferragens
  |    +- Fita Borda
  |    +- Usinagens CNC
  |    +- Orcamento Completo
  |    +- Orcamento CSV
  |    +- XML OpenCutList
  |    +- Corte Certo
  +- Salvar como Template
  +- Propriedades
```

### 17.3 Menu de Contexto (right-click)

Ao clicar com botao direito em um modulo Ornato:

```
Ornato: [Nome do Modulo]
  +- Propriedades do Modulo
  +- Adicionar Agregado > (Porta, Porta Dupla, Gaveta, Prateleira, Divisoria)
  +- Porta Especial > (Lisa, Provencal, Almofadada, Vidro, ...)
  +- Dividir Vao > (Horizontal, Vertical)
  +- Relatorios > (Lista Pecas, Mapa Furacao, Usinagens CNC, Fita Borda, Orcamento)
  +- Alinhar/Distribuir > (Horizontal, Profundidade, Altura, Empilhar, Distribuir, Espelhar)
  +- Salvar como Template
  +- Duplicar Modulo
  +- Editar Dimensoes
  +- Trocar Material
```

Ao selecionar multiplos modulos:
```
Ornato: N modulos
  +- Alinhar Horizontal
  +- Alinhar Profundidade
  +- Alinhar Altura
  +- Empilhar Vertical
  +- Distribuir c/ 3mm
  +- Orcamento Selecionados
```

### 17.4 Painel Principal

- **Aba Projeto**: Lista de modulos por ambiente, total de modulos e pecas
- **Aba Exportar**: Botoes de exportacao organizados (Listas, Detalhamento)
- Barra de ferramentas rapida com botoes coloridos
- Cor de fundo: laranja Ornato (#e67e22)

### 17.5 Painel Propriedades

- Dimensoes do modulo (largura, altura, profundidade)
- Material corpo e frente (dropdown da biblioteca)
- Fita de borda corpo e frente (dropdown da biblioteca)
- Botoes de acao: Mapa Furacao, Usinagens, Aplicar Fita

---

## 18. METODOS DE INSTALACAO DE FUNDO

| Metodo            | Descricao                              | Melhor para              |
|-------------------|----------------------------------------|--------------------------|
| Canal fresado     | Canal nos 4 lados, fundo desliza       | Melhor esquadria, padrao |
| Sobreposto        | Grampeado/pregado na traseira          | Rapido, facil reposicao  |
| Rebaixo           | Rebaixo nas bordas traseiras           | Visual limpo pela tras   |
| Dividido          | 2 paineis + montante central           | Modulos > 900mm largura  |

---

## 19. FLUXO DE TRABALHO DO PROJETISTA

### Passo 1: Criar modulos
- Usar toolbar ou menu Templates para criar modulos
- Definir dimensoes, material, tipo de montagem

### Passo 2: Adicionar agregados
- Selecionar modulo, clicar no vao desejado
- Adicionar portas, gavetas, prateleiras, divisorias
- Portas especiais (vidro, veneziana, provencal, etc.)

### Passo 3: Pecas avulsas
- Tampos, rodapes, requadros, paineis laterais
- Paineis cavilhados, molduras, canaletas LED

### Passo 4: Alinhar e posicionar
- Alinhar modulos horizontalmente
- Empilhar superior sobre inferior
- Distribuir com espacamento

### Passo 5: Revisar e editar
- Right-click para propriedades
- Editar dimensoes, trocar materiais
- Verificar lista de pecas e ferragens

### Passo 6: Exportar para producao
- Lista de corte CSV
- Plano de corte otimizado
- Sequencia esquadrejadeira
- Mapa de furacao
- Lista de ferragens
- Usinagens CNC
- Orcamento completo

---

## 20. REGRAS DE NEGOCIO IMPORTANTES

1. **Montagem padrao Brasil**: Laterais entre base e topo (SEMPRE verificar)
2. **Sistema 32mm**: Todos os furos alinhados na grade 32mm
3. **Folga de porta**: 2mm padrao (cada lado)
4. **Folga entre gavetas**: 3mm vertical
5. **Corredica snap**: Sempre usar comprimento padrao mais proximo
6. **Fita automatica**: Aplicada conforme regras de visibilidade
7. **Caneco automatico**: Gerado para todas as portas (exceto vidro inteiro e aluminio)
8. **Canal de fundo automatico**: Gerado na construcao da carcaca
9. **Validacao colisao**: Sempre verificar antes de exportar
10. **Preco venda = custo x 1.35**: Margem padrao 35%

---

## 21. O QUE FALTA IMPLEMENTAR / MELHORIAS FUTURAS

### Alta Prioridade
- [ ] Representacao visual 3D das usinagens (canais, pockets desenhados na geometria)
- [ ] Exportacao DXF para CNC (coordenadas de furacao e usinagem)
- [ ] Exportacao PDF (lista de corte formatada para impressao)
- [ ] Integracao com ERP Ornato (sincronizacao de materiais e precos)
- [ ] Desfazer/Refazer integrado (SketchUp undo support completo)

### Media Prioridade
- [ ] Preview 3D de templates antes de colocar
- [ ] Drag-and-drop de agregados entre vaos
- [ ] Copia de agregados entre modulos
- [ ] Portas de correr com trilho superior/inferior
- [ ] Porta basculante com pistao gas (calculo automatico)
- [ ] Nicho para eletrodomesticos (recortes pre-definidos)
- [ ] Sistema de iluminacao (spots e fita LED)
- [ ] Puxadores 3D posicionados na geometria

### Baixa Prioridade
- [ ] Animacao de abertura (portas abrindo, gavetas puxando)
- [ ] Render materializado (aplicar texturas reais)
- [ ] Modo AR (realidade aumentada via SketchUp Viewer)
- [ ] Multi-idioma (EN, ES)
- [ ] Plugin marketplace SketchUp (Extension Warehouse)

---

## 22. COMO INSTALAR

1. Compactar a pasta `ornato_plugin/` + arquivo `ornato_plugin.rb` em um `.rbz`
2. No SketchUp: `Janela > Gerenciador de Extensoes > Instalar Extensao`
3. Selecionar o arquivo `.rbz`
4. Reiniciar o SketchUp
5. A toolbar e menu "Ornato" aparecerao automaticamente

### Criar o .rbz manualmente:
```bash
cd "/Users/madeira/SISTEMA SKETCHUP"
zip -r ornato_plugin.rbz ornato_plugin.rb ornato_plugin/ -x "*.DS_Store"
```

---

## 23. CONTATO E CREDITOS

- **Plugin**: Ornato Marcenaria v0.1.0
- **Desenvolvedor**: Victor Madeira / Ornato
- **Repositorio**: https://github.com/victormadeira/ORNATOSKETCHUP
- **Copyright**: 2026 Ornato
- **Assistente IA**: Claude Opus (Anthropic)
