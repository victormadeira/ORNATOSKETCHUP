# Planejamento Estratégico — Plugin Ornato SketchUp
# Análise Crítica do UpMobb + Proposta de Sistema Superior

> Documento gerado em 28/02/2026
> Baseado na análise completa do UpMobb V2.10.22
> Objetivo: Criar o melhor plugin de marcenaria paramétrica do Brasil

---

## PARTE 1 — FALHAS E LIMITAÇÕES DO UPMOBB

### 1.1 Processamento Apenas na Nuvem

**Observação**: O UpMobb processa tudo (plano de corte, G-code, etiquetas,
orçamento) na plataforma online. Rodar online é uma abordagem válida,
mas significa que toda inteligência de produção está fora do plugin.

**Nota**: O Ornato pode adotar modelo híbrido — online para funcionalidades
avançadas, mas com capacidade de processamento local como diferencial.

### 1.2 Ausência de Templates de Ambiente

**Problema**: Zero templates prontos. Cada projeto começa do zero.

**Impacto**:
- Projetista gasta 2-4h para montar uma cozinha simples
- Marcenarias menores não têm projetista dedicado
- Repetição manual de configurações comuns
- Barreira de entrada para novos usuários

### 1.3 Nomenclatura Confusa de Modelos de Caixa

**Problema**: "modelo 01, modelo 02... modelo 18" sem descrição.

**Impacto**:
- Usuário precisa clicar em cada um para entender a diferença
- Curva de aprendizado alta
- Erros de seleção frequentes

### 1.4 Sistema de Trocas Fragmentado

**Problema**: 11 grupos de trocas com itens repetidos. Fixação Divisoria,
Fixação Lateral, Fixação Prateleira e Fixação Régua Deitada compartilham
90% dos mesmos kits.

**Impacto**:
- Interface poluída com duplicação
- Usuário não sabe a diferença entre os grupos
- Manutenção do catálogo ineficiente

### 1.5 Sem Inteligência de Ferragem

**Problema**: O usuário precisa escolher manualmente CADA ferragem
(tipo de dobradiça, tipo de corrediça, tipo de fixação).

**Impacto**:
- Erros humanos frequentes (dobradiça errada para o peso da porta)
- Projetista precisa conhecer cada ferragem
- Tempo perdido em seleções manuais
- Não valida se a ferragem é compatível com o módulo

### 1.6 Sem Validação de Projeto

**Problema**: O sistema de alertas existe mas é básico. Não previne
configurações impossíveis na modelagem.

**Impacto**:
- Gaveta configurada maior que o vão disponível
- Porta que bate na outra ao abrir
- Espessura de material incompatível com ferragem
- Erros só descobertos na fábrica

### 1.7 Interface Sobrecarregada

**Problema**: 14 ícones na barra lateral, múltiplos painéis flutuantes,
painéis de configuração longos com scroll.

**Impacto**:
- Curva de aprendizado de semanas
- Projetistas experientes ainda perdem tempo navegando
- Configurador de componentes exige muito scroll

### 1.8 Sem Integração com Eletrodomésticos

**Problema**: Não há biblioteca de eletrodomésticos (fogão, cooktop,
forno, micro-ondas, lava-louça) com recortes automáticos.

**Impacto**:
- Projetista precisa fazer recortes manualmente
- Não há validação de espaço para o eletrodoméstico
- Nichos de forno/micro-ondas são manuais

### 1.9 Sem Visualização de Custo em Tempo Real

**Problema**: Custo só é calculado após exportar para plataforma online.

**Impacto**:
- Projetista finaliza o projeto sem saber se cabe no orçamento do cliente
- Retrabalho quando o preço excede o budget
- Sem poder de negociação durante a reunião com o cliente

### 1.10 Sem Plano de Corte Local

**Problema**: Otimização de chapas feita apenas online.

**Impacto**:
- Não sabe o desperdício de material antes de finalizar
- Impossível comparar otimizações com diferentes configurações
- Dependência de internet para operação crítica de fábrica

---

## PARTE 2 — VISÃO DO PLUGIN ORNATO

### 2.1 Filosofia

> **"Do projeto à produção em um único lugar, sem depender de ninguém."**

O Ornato deve ser um sistema **autossuficiente** que funciona 100% offline
e se integra opcionalmente ao ERP para funcionalidades avançadas.

### 2.2 Os 5 Pilares do Ornato

```
┌──────────────────────────────────────────────────────────┐
│                    PLUGIN ORNATO                         │
├────────────┬────────────┬──────────┬──────────┬─────────┤
│ 1. MODELAR │ 2. VALIDAR │ 3. CUSTO │ 4. CORTE │ 5. CNC │
│ Paramétri- │ Regras de  │ Preço em │ Plano de │ G-code  │
│ co c/ inte │ engenharia │ tempo    │ corte    │ local   │
│ ligência   │ automáti-  │ real     │ otimiza- │         │
│            │ cas        │          │ do local │         │
└────────────┴────────────┴──────────┴──────────┴─────────┘
```

---

## PARTE 3 — FEATURES DE UPGRADE (ALÉM DO UPMOBB)

### 3.1 🧠 Motor de Inteligência Automática (NOVO)

**O que faz**: Escolhe automaticamente as ferragens corretas com base
nas dimensões e tipo do módulo.

```ruby
# Exemplo de lógica em motor_inteligencia.rb
def auto_selecionar_dobradica(porta)
  peso = calcular_peso_porta(porta)
  tipo = porta.tipo_abertura  # giro, sobreposta, embutida

  if peso <= 3.0
    return { tipo: :reta, marca: :blum, modelo: 'clip_standard' }
  elsif peso <= 6.0
    return { tipo: :reta, marca: :blum, modelo: 'blumotion' }
  elsif peso <= 10.0
    return { tipo: :reta, marca: :blum, modelo: 'blumotion_heavy' }
  end
end

def auto_selecionar_corredica(gaveta)
  profundidade = gaveta.profundidade
  peso_estimado = calcular_peso_gaveta(gaveta)

  if peso_estimado <= 15 && profundidade <= 400
    return { tipo: :telescopica, carga: '25kg' }
  elsif peso_estimado <= 30
    return { tipo: :oculta_tandem, carga: '30kg' }
  else
    return { tipo: :tandembox, carga: '50kg' }
  end
end

def auto_selecionar_fixacao(peca, conexao_tipo)
  espessura = peca.espessura

  if espessura >= 15 && conexao_tipo == :definitiva
    return :minifix_com_cavilha
  elsif espessura >= 15 && conexao_tipo == :desmontavel
    return :minifix_twister
  elsif espessura < 15
    return :cavilha_dupla
  end
end
```

**Benefício**: Projetista NÃO precisa saber de ferragens.
O sistema sugere a melhor opção e o projetista apenas confirma ou troca.

### 3.2 🏠 Motor de Ambiente (NOVO — Diferencial)

**O que faz**: Define o ambiente (paredes, piso, pé-direito) e auto-posiciona módulos.

```ruby
# motor_ambiente.rb
class MotorAmbiente
  def criar_cozinha_em_l(largura_1, largura_2, pe_direito, profundidade)
    # 1. Desenha paredes guia (camada auxiliar)
    # 2. Calcula quantidade de módulos inferiores
    # 3. Insere módulos inferiores com snap automático
    # 4. Calcula aéreos correspondentes
    # 5. Insere aéreos alinhados com inferiores
    # 6. Insere tampo contínuo
    # 7. Insere rodapé contínuo
    # 8. Configura canto oblíquo/reto automaticamente
  end
end
```

**Templates prontos**:
- Cozinha: Linear | Em L | Em U | Paralela | Com Ilha
- Dormitório: Closet Linear | Closet em L | Guarda-roupa Embutido
- Banheiro: Gabinete + Espelheira | Coluna
- Lavanderia: Armário + Bancada
- Escritório: Estante + Mesa | Home Office

### 3.3 ✅ Motor de Validação (NOVO)

**O que faz**: Valida o projeto em tempo real e impede erros de engenharia.

```ruby
# motor_validacao.rb
REGRAS = {
  # Estruturais
  vao_max_sem_divisoria: 900,        # mm - acima disso, precisa divisória
  vao_min_gaveta: 250,               # mm - mínimo para caber uma gaveta
  altura_min_modulo: 200,            # mm
  profundidade_max_balcao: 650,      # mm

  # Ferragem
  distancia_min_dobradica_borda: 70, # mm
  quantidade_dobradicas: {           # por altura da porta
    ate_600: 2,
    600_a_1200: 3,
    1200_a_1800: 4,
    acima_1800: 5
  },

  # Portas
  folga_porta_sobreposta: 2,         # mm entre portas
  folga_porta_embutida: 3,           # mm
  peso_max_porta_giro: 12,           # kg

  # Gavetas
  folga_lateral_gaveta: {
    telescopica: 12.7,               # mm por lado
    oculta_tandem: 42.0,             # mm total
    tandembox: 75.0,                 # mm total (37.5 por lado)
  },

  # Material
  espessura_min_tampo: 25,           # mm
  espessura_min_lateral: 15,         # mm
  espessura_fundo_rasgo: 3,          # mm (MDF 3mm em rasgo)
  espessura_fundo_sobreposto: 6,     # mm (MDF 6mm sobreposto)
}

def validar_modulo(modulo)
  alertas = []

  # Vão sem divisória
  if modulo.largura_interna > REGRAS[:vao_max_sem_divisoria]
    alertas << {
      tipo: :aviso,
      msg: "Vão de #{modulo.largura_interna}mm sem divisória. Recomendado máx 900mm.",
      sugestao: "Adicionar divisória central"
    }
  end

  # Porta pesada demais para dobradiça selecionada
  modulo.portas.each do |porta|
    if porta.peso > REGRAS[:peso_max_porta_giro]
      alertas << {
        tipo: :erro,
        msg: "Porta #{porta.nome} pesa #{porta.peso}kg. Máx para giro: 12kg.",
        sugestao: "Usar porta de correr ou dividir em duas folhas"
      }
    end
  end

  alertas
end
```

### 3.4 💰 Precificação em Tempo Real (NOVO)

**O que faz**: Mostra o custo estimado do projeto enquanto o projetista modela.

```
┌────────────────────────────────────────────┐
│  💰 CUSTO ESTIMADO DO PROJETO              │
│                                            │
│  Chapas MDF 15mm:  12.5 chapas  R$ 2.500  │
│  Chapas MDF 18mm:   3.2 chapas  R$ 800    │
│  Fitas de borda:    85m          R$ 170    │
│  Dobradiças:        24un         R$ 480    │
│  Corrediças:        8 pares      R$ 640    │
│  Minifix:           96un         R$ 192    │
│  Puxadores:         16un         R$ 320    │
│  ──────────────────────────────────────    │
│  MATERIAL:                       R$ 5.102  │
│  MÃO DE OBRA (est):             R$ 2.800  │
│  ──────────────────────────────────────    │
│  TOTAL:                          R$ 7.902  │
│  COM MARKUP 40%:                 R$ 11.063 │
└────────────────────────────────────────────┘
```

- Integra com tabela de preços do ERP Ornato
- Atualiza automaticamente a cada módulo adicionado/modificado
- Permite exportar orçamento em PDF direto do SketchUp

### 3.5 📐 Plano de Corte Local (UPGRADE)

**O que faz**: Gera o plano de corte otimizado DENTRO do plugin,
sem precisar de internet.

- Algoritmo FFD (First Fit Decreasing) já no projeto
- Visualização gráfica do plano no painel
- Mostra desperdício % por chapa
- Sequenciamento para esquadrejadeira
- Exporta em PDF/DXF para a fábrica

### 3.6 🏷️ Etiquetas Locais (UPGRADE)

**O que faz**: Gera etiquetas de cada peça direto no plugin.

- Código de barras / QR Code por peça
- Dados: nome da peça, dimensões, material, fita de borda, módulo pai
- Layout customizável
- Impressão direta ou exportação PDF

### 3.7 🔌 Biblioteca de Eletrodomésticos (NOVO)

**O que faz**: Catálogo de eletrodomésticos com dimensões reais e recortes automáticos.

```ruby
ELETRODOMESTICOS = {
  cooktop_4bocas:   { largura: 590, profundidade: 510, recorte_l: 560, recorte_p: 490 },
  cooktop_5bocas:   { largura: 770, profundidade: 510, recorte_l: 738, recorte_p: 490 },
  forno_embutir_60: { largura: 595, altura: 595, profundidade: 565, nicho_l: 560, nicho_a: 585 },
  forno_embutir_90: { largura: 895, altura: 595, profundidade: 565, nicho_l: 860, nicho_a: 585 },
  micro_embutir:    { largura: 595, altura: 380, profundidade: 410, nicho_l: 560, nicho_a: 380 },
  lava_louca:       { largura: 598, altura: 820, profundidade: 550 },
  geladeira_bt:     { largura: 695, altura: 1780, profundidade: 705 },
  coifa_60:         { largura: 600, profundidade: 450, altura_min_cooktop: 650 },
  coifa_90:         { largura: 900, profundidade: 450, altura_min_cooktop: 650 },
  cuba_inox_simples:{ largura: 560, profundidade: 340, recorte_l: 540, recorte_p: 320 },
  cuba_inox_dupla:  { largura: 840, profundidade: 340, recorte_l: 820, recorte_p: 320 },
}
```

- Ao inserir um cooktop, o tampo recebe o recorte automático
- Ao inserir um forno, o módulo ganha nicho com ventilação
- Validação automática: espaço suficiente? Ventilação adequada?

### 3.8 🎨 Temas de Acabamento (NOVO)

**O que faz**: Aplica um esquema de cores/materiais inteiro com um clique.

```
Tema "Moderno Branco":
  - Caixas: MDF Branco TX 15mm
  - Portas: MDF Branco TX 18mm
  - Tampo: Quartzo Branco
  - Puxadores: Perfil alumínio
  - Fita de borda: Branco TX 0.45mm

Tema "Rústico Natural":
  - Caixas: MDF Carvalho 15mm
  - Portas: MDF Carvalho 18mm Provençal
  - Tampo: Granito Preto
  - Puxadores: Alça bronze
  - Fita de borda: Carvalho 1mm
```

### 3.9 📋 Fita de Borda Automática (UPGRADE)

**O que faz**: Aplica regras automáticas de fita de borda baseadas na visibilidade.

```ruby
# motor_fita_borda.rb — regras automáticas
REGRAS_FITA = {
  lateral_externa:    { frente: true, topo: true, fundo: false, base: false },
  lateral_interna:    { frente: true, topo: false, fundo: false, base: false },
  base:               { frente: true, topo: false, fundo: false, base: false },
  tampo:              { frente: true, topo: false, fundo: false, base: false },
  prateleira:         { frente: true, topo: false, fundo: false, base: false },
  porta:              { frente: false, topo: true, fundo: true, base: true, esquerda: true, direita: true }, # 4 lados
  frente_gaveta:      { topo: true, fundo: true, esquerda: true, direita: true }, # 4 lados
  fundo:              { nenhum: true },
  divisoria:          { frente: true, topo: false, fundo: false, base: false },
}

# Aplicação: ao gerar peça, consulta a regra automaticamente
# Projetista pode sobrescrever manualmente se necessário
```

### 3.10 📱 Modo Apresentação para Cliente (NOVO)

**O que faz**: Modo de visualização limpo para apresentar ao cliente.

- Esconde todas as linhas de construção
- Aplica materiais renderizados (texturas reais)
- Mostra dimensões principais
- Mostra preço total (opcional)
- Permite "abrir portas e gavetas" interativamente
- Exporta vistas (frontal, perspectiva, planta) em PDF

### 3.11 📋 Detalhamento Rápido de Módulos (NOVO — ESSENCIAL PARA MARCENEIRO)

**O que faz**: Seleciona um módulo → gera automaticamente a **ficha técnica completa**
com tudo que o marceneiro precisa para fabricar aquele módulo.

**O problema hoje**: O marceneiro modela em 3D, mas depois precisa gastar horas
criando desenhos técnicos 2D para a oficina. Muitos simplesmente não fazem
e cortam "de cabeça", gerando erros.

**Solução — Ficha Técnica Automática por módulo:**

```
╔══════════════════════════════════════════════════════════════╗
║  FICHA TÉCNICA — Balcão Pia Cozinha (Módulo 03)            ║
║  Projeto: Cozinha Sra. Maria | Data: 28/02/2026            ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  ┌─────────────┐  ┌──────────┐  ┌──────────┐               ║
║  │  VISTA      │  │ VISTA    │  │ VISTA    │               ║
║  │  FRONTAL    │  │ LATERAL  │  │ SUPERIOR │               ║
║  │  (com cotas)│  │ (corte)  │  │ (planta) │               ║
║  └─────────────┘  └──────────┘  └──────────┘               ║
║                                                              ║
║  DIMENSÕES GERAIS: 800 x 870 x 550mm                       ║
║  Material: MDF Branco TX 15mm | Tampo: Granito 20mm        ║
║                                                              ║
║  ┌──────────────────────────────────────────────────────┐   ║
║  │ LISTA DE PEÇAS                                       │   ║
║  ├──────────────────┬──────────┬───────┬───────┬────────┤   ║
║  │ Peça             │ Dimensão │ Qtd   │ Mat.  │ Fita   │   ║
║  ├──────────────────┼──────────┼───────┼───────┼────────┤   ║
║  │ Lateral ESQ      │ 720x550  │ 1     │ BR TX │ 1C     │   ║
║  │ Lateral DIR      │ 720x550  │ 1     │ BR TX │ 1C     │   ║
║  │ Base             │ 770x550  │ 1     │ BR TX │ 1C     │   ║
║  │ Travessa Sup     │ 770x80   │ 1     │ BR TX │ 1C     │   ║
║  │ Fundo            │ 770x720  │ 1     │ BR TX │ —      │   ║
║  │ Porta Lisa       │ 717x397  │ 2     │ BR TX │ 4L     │   ║
║  └──────────────────┴──────────┴───────┴───────┴────────┘   ║
║                                                              ║
║  ┌──────────────────────────────────────────────────────┐   ║
║  │ FERRAGENS                                            │   ║
║  ├──────────────────┬───────┬───────────────────────────┤   ║
║  │ Dobradiça Blum   │ 4 un  │ Reta c/ amortecedor      │   ║
║  │ Minifix 15mm     │ 8 un  │ Fixação lateral/base      │   ║
║  │ Cavilha 8mm      │ 8 un  │ Alinhamento               │   ║
║  │ Puxador Alça     │ 2 un  │ 160mm alumínio            │   ║
║  │ Pé regulável     │ 4 un  │ Altura 100-150mm          │   ║
║  └──────────────────┴───────┴───────────────────────────┘   ║
║                                                              ║
║  ┌──────────────────────────────────────────────────────┐   ║
║  │ MAPA DE FURAÇÃO (Lateral ESQ — face interna)         │   ║
║  │                                                       │   ║
║  │  ●(37,32) ●(37,64)     Minifix Ø15 prof.12.5mm      │   ║
║  │  ○(37,48)               Cavilha Ø8 prof.12mm         │   ║
║  │                                                       │   ║
║  │  ●(37,688) ●(37,720)   Minifix topo                  │   ║
║  │  ○(37,704)              Cavilha topo                  │   ║
║  │                                                       │   ║
║  │  ◆(22,100)              Dobradiça Ø35 prof.12mm      │   ║
║  │  ◆(22,620)              Dobradiça Ø35 prof.12mm      │   ║
║  └──────────────────────────────────────────────────────┘   ║
║                                                              ║
║  [QR Code → Link para vista 3D interativa]                  ║
╚══════════════════════════════════════════════════════════════╝
```

**Geração**: 1 clique → seleciona módulo → "Gerar Ficha Técnica"
**Formato**: PDF exportável ou visualização no painel
**Inclui**: Vistas 2D cotadas, lista de peças, ferragens, mapa de furação

### 3.12 🏷️ Sistema de Etiquetas Inteligentes (NOVO — ESSENCIAL PARA MARCENEIRO)

**O que faz**: Cada peça cortada recebe uma etiqueta que diz EXATAMENTE
o que ela é e onde vai.

**O problema hoje**: Marceneiro corta 50 peças, empilha, e depois não sabe
qual é qual. "Essa lateral é do módulo da pia ou do forno?" → Mede de novo,
perde tempo, erra.

**Modelo de etiqueta por peça:**

```
┌─────────────────────────────────────────────┐
│ ■■■■■ CÓDIGO DE BARRAS ■■■■■               │
│                                              │
│ LATERAL ESQUERDA                             │
│ Módulo: Balcão Pia (M03)                     │
│ Ambiente: Cozinha                            │
│                                              │
│ Dimensões: 720 x 550 x 15mm                 │
│ Material:  MDF Branco TX 15mm                │
│                                              │
│ FITA DE BORDA:                               │
│ ┌────────────────┐                           │
│ │    ▲ TOPO      │ ← sem fita               │
│ │ E  │         D │                           │
│ │ S  │         I │                           │
│ │ Q  │         R │ ← sem fita               │
│ │    │           │                           │
│ │    ▼ BASE     │ ← sem fita               │
│ └────────────────┘                           │
│    ▲ FRENTE ← FITA BRANCA 22mm              │
│                                              │
│ FURAÇÃO: Face interna                        │
│ • 2x Minifix Ø15 (base)                     │
│ • 1x Cavilha Ø8 (base)                      │
│ • 2x Minifix Ø15 (topo)                     │
│ • 2x Dobradiça Ø35 (frente)                 │
│                                              │
│ Projeto: Cozinha Sra. Maria                  │
│ Peça 03/24 | 28/02/2026                      │
│ [QR CODE]                                    │
└─────────────────────────────────────────────┘
```

**Informações na etiqueta:**
1. **Nome da peça** em destaque (LATERAL ESQUERDA, não "CM_LAT_ESQ")
2. **Módulo pai** com nome descritivo (Balcão Pia, não "M03")
3. **Ambiente** (Cozinha, Dormitório, etc.)
4. **Dimensões** líquidas (já descontado rasgo se houver)
5. **Material** com acabamento
6. **Diagrama de fita de borda** visual (mostra quais lados têm fita)
7. **Resumo de furação** (quantos furos, que tipo)
8. **Numeração sequencial** (peça 03/24 = terceira de 24 peças totais)
9. **QR Code** que linka para vista 3D do módulo ou ficha técnica

**Agrupamentos inteligentes de impressão:**
- Por módulo (todas as peças do Balcão Pia juntas)
- Por material (todas as peças MDF Branco juntas — otimiza corte)
- Por espessura (todas 15mm juntas, depois 18mm)
- Por ambiente (todas da cozinha, depois dormitório)

### 3.13 💥 Vista Explodida Automática (NOVO)

**O que faz**: Gera automaticamente uma vista explodida do módulo mostrando
como as peças se encaixam, com setas indicando a montagem.

```
Vista normal:                Vista explodida:
┌──────────┐                    ╭─── tampo
│          │                ┌───┴──────┐
│  MÓDULO  │       ←──     │          │
│          │              ┌─┤          ├─┐
└──────────┘              │ │  ← base │ │
                          │ └─────────┘ │ ← laterais
                          └─────┬───────┘
                                │
                           ┌────┴────┐  ← fundo
                           └─────────┘
```

- Geração automática a partir da geometria do módulo
- Setas numeradas indicando ordem de montagem
- Pode ser exportada como imagem/PDF
- Útil para treinar montadores ou terceirizar montagem

### 3.14 📊 Agrupamento de Peças Iguais (NOVO)

**O que faz**: Identifica automaticamente peças com dimensões e material idênticos
em todo o projeto e agrupa para corte conjunto.

```
┌──────────────────────────────────────────────────────────┐
│  PEÇAS IGUAIS — AGRUPAR PARA CORTE                       │
│                                                           │
│  Grupo 1: 720 x 550 x 15mm MDF Branco TX                │
│  → 8 laterais (de 4 módulos diferentes)                  │
│  → Corte todas de uma vez na esquadrejadeira             │
│                                                           │
│  Grupo 2: 770 x 550 x 15mm MDF Branco TX                │
│  → 4 bases (de 4 módulos)                                │
│                                                           │
│  Grupo 3: 717 x 397 x 18mm MDF Branco TX                │
│  → 8 portas (todas iguais!)                              │
│                                                           │
│  Grupo 4: 770 x 80 x 15mm MDF Branco TX                 │
│  → 4 travessas superiores                                │
│                                                           │
│  TOTAL: 24 peças em 4 grupos (em vez de 24 medidas)      │
│  ECONOMIA DE TEMPO: ~45 minutos no corte                 │
└──────────────────────────────────────────────────────────┘
```

**Benefício**: Em vez de medir e cortar 24 peças individualmente,
o marceneiro configura a esquadrejadeira 4 vezes e corta em lote.

### 3.15 🔧 Roteiro de Produção (NOVO)

**O que faz**: Gera a sequência completa de produção, passo a passo.

```
ROTEIRO DE PRODUÇÃO — Cozinha Sra. Maria
═══════════════════════════════════════

ETAPA 1: CORTE (esquadrejadeira)
  □ Configurar para MDF 15mm Branco TX
    □ Cortar 8x laterais 720x550
    □ Cortar 4x bases 770x550
    □ Cortar 4x travessas 770x80
    □ Cortar 4x fundos 770x720 (MDF 3mm)
  □ Trocar para MDF 18mm Branco TX
    □ Cortar 8x portas 717x397

ETAPA 2: FITA DE BORDA
  □ Fita Branca 22mm (bordas frontais)
    □ 8x laterais (1 lado = frente)
    □ 4x bases (1 lado = frente)
    □ 4x travessas (1 lado = frente)
  □ Fita Branca 44mm (portas = 4 lados)
    □ 8x portas (todos os lados)

ETAPA 3: FURAÇÃO
  □ Broca Ø35mm (dobradiças)
    □ 8x laterais — face interna, 2 furos cada
  □ Broca Ø15mm (minifix)
    □ 8x laterais — 4 furos cada (base + topo)
    □ 4x bases — 4 furos cada (laterais)
  □ Broca Ø8mm (cavilha)
    □ 8x laterais — 2 furos cada
    □ 4x bases — 2 furos cada

ETAPA 4: MONTAGEM
  □ Módulo 01 (Balcão Pia)
    □ Montar caixa (laterais + base + travessa)
    □ Fixar fundo
    □ Instalar dobradiças nas laterais
    □ Fixar portas nas dobradiças
    □ Instalar puxadores
  □ Módulo 02 (Balcão Gavetas)
    □ ...

ETAPA 5: ACABAMENTO
  □ Retocar bordas expostas
  □ Limpar módulos
  □ Embalar para transporte

ETAPA 6: INSTALAÇÃO
  □ Nivelar base com pés reguláveis
  □ Fixar módulos entre si
  □ Fixar aéreos na parede
  □ Instalar tampo
  □ Ajustar portas e gavetas
  □ Passar silicone (tampo/parede)
```

### 3.16 ⚡ Features para o PROJETISTA (velocidade + apresentação)

**O projetista precisa de**: VELOCIDADE na criação, BELEZA na apresentação,
FLEXIBILIDADE nas alterações.

#### 3.16.1 Módulos Pré-Dimensionados por Função

Em vez de inserir "balcão genérico" e configurar tudo, o projetista escolhe
direto o módulo pela FUNÇÃO:

```
COZINHA:
├── Módulo Pia          → 800mm (padrão cuba simples) / 1200mm (cuba dupla)
├── Módulo Cooktop      → 600mm (4 bocas) / 900mm (5 bocas)
├── Módulo Forno        → 600mm (c/ nicho 60) / 900mm (c/ nicho 90)
├── Módulo Micro-ondas  → 600mm (c/ nicho)
├── Módulo Lava-louça   → 600mm (c/ abertura frontal)
├── Módulo Gavetas      → 400/500/600mm (3 ou 4 gavetas)
├── Módulo Portas       → 300/400/500/600mm (1 ou 2 portas)
├── Módulo Canto L      → 900x900mm / 1000x1000mm
├── Módulo Canto Oblíquo→ com lazy susan
├── Módulo Lixeira      → 300/400mm
├── Módulo Tempero      → 150/200mm (pull-out)
└── Aéreo Coifa         → 600/900mm (esconde coifa)

DORMITÓRIO:
├── Módulo Cabideiro    → 800mm (altura padrão cabide)
├── Módulo Prateleiras  → 600mm (5 prateleiras)
├── Módulo Gaveteiro    → 500mm (4 gavetas roupa)
├── Módulo Sapateira    → 600mm (prateleiras inclinadas)
├── Módulo Maleiro      → sobre os módulos (altura variável)
└── Módulo Espelho      → porta com espelho interno
```

**Benefício**: Insere módulo → já vem com agregados corretos
(pia já vem com fundo horizontal, forno já vem com nicho e ventilação).

#### 3.16.2 Duplicar e Espelhar

- **Duplicar módulo**: Ctrl+D → cópia idêntica pronta para posicionar
- **Espelhar módulo**: Ctrl+M → espelho (lateral esquerda vira direita)
- **Duplicar ambiente inteiro**: Para fazer variação do projeto

#### 3.16.3 Múltiplas Opções de Orçamento (3 níveis)

O projetista cria UM projeto e gera 3 orçamentos com materiais diferentes:

```
┌─────────────────────────────────────────────────────────┐
│  OPÇÕES DE ORÇAMENTO — Cozinha Sra. Maria               │
│                                                          │
│  OPÇÃO 1 — ECONÔMICO                     R$ 8.500       │
│  MDF Branco 15mm, portas lisas, puxador alça simples    │
│  Dobradiça standard, corrediça telescópica               │
│                                                          │
│  OPÇÃO 2 — PADRÃO                        R$ 12.800      │
│  MDF Branco TX 18mm, portas freijó, puxador perfil AL   │
│  Dobradiça Blum c/ amortecedor, corrediça oculta        │
│                                                          │
│  OPÇÃO 3 — PREMIUM                       R$ 18.500      │
│  MDF Carvalho 18mm, portas provençal, puxador cava      │
│  Dobradiça Blum blumotion, Tandembox Blum               │
└─────────────────────────────────────────────────────────┘
```

**Benefício**: Cliente escolhe na hora. Projetista não precisa
refazer o projeto 3 vezes — só troca a "camada de acabamento".

#### 3.16.4 Cotagem Automática no 3D

- Ao selecionar módulo: exibe cotas principais automaticamente
- Cota geral (largura, altura, profundidade)
- Cotas internas (vãos, divisórias)
- Toggle ON/OFF por camada
- Exportável como vista 2D cotada

#### 3.16.5 Histórico de Projetos / Clonar e Adaptar

```
PROJETOS RECENTES:
├── Cozinha em L — Sr. João (dez/2025) → [Clonar] [Abrir]
├── Closet Casal — Sra. Ana (jan/2026) → [Clonar] [Abrir]
├── Banheiro Suite — Sr. Pedro (fev/2026) → [Clonar] [Abrir]
```

- Clonar projeto anterior como base
- Adaptar dimensões ao novo ambiente
- Reaproveitar configurações de acabamento
- Economiza 50%+ do tempo em projetos similares

#### 3.16.6 Render Rápido para Redes Sociais / Portfólio

- Modo "foto" com iluminação pré-configurada
- Backgrounds prontos (parede branca, tijolo, concreto)
- Exporta em alta resolução para Instagram/Portfolio
- Marca d'água da marcenaria (logo do cliente)

---

## PARTE 4 — ARQUITETURA TÉCNICA PROPOSTA

### 4.1 Estrutura de Arquivos Atualizada

```
ornato_plugin/
├── main.rb                    # Loader principal
├── config.rb                  # Configurações globais
├── utils.rb                   # Utilitários
│
├── models/                    # Modelos de dados
│   ├── peca.rb                # Peça individual
│   ├── vao.rb                 # Vão (abertura)
│   ├── modulo_info.rb         # Informações do módulo
│   ├── material_info.rb       # Material e acabamento
│   ├── ferragem_info.rb       # [NOVO] Dados de ferragem
│   └── ambiente_info.rb       # [NOVO] Dados do ambiente
│
├── engines/                   # Motores de processamento
│   ├── motor_caixa.rb         # Geração de carcaças
│   ├── motor_agregados.rb     # Sistema de agregados
│   ├── motor_furacao.rb       # Furação paramétrica
│   ├── motor_fita_borda.rb    # Fita de borda AUTO
│   ├── motor_usinagem.rb      # Usinagens CNC
│   ├── motor_portas.rb        # Sistema de portas
│   ├── motor_pecas_avulsas.rb # Peças independentes
│   ├── motor_plano_corte.rb   # Plano de corte LOCAL
│   ├── motor_templates.rb     # Templates de ambiente
│   ├── motor_precificacao.rb  # Preço em tempo real
│   ├── motor_alinhamento.rb   # Snap entre módulos
│   ├── motor_inteligencia.rb  # [NOVO] Auto-seleção ferragem
│   ├── motor_validacao.rb     # [NOVO] Regras de engenharia
│   ├── motor_ambiente.rb      # [NOVO] Definição de ambiente
│   ├── motor_etiquetas.rb     # [NOVO] Etiquetas locais
│   └── motor_export.rb        # [NOVO] Export JSON/DXF/PDF
│
├── tools/                     # Ferramentas SketchUp
│   ├── caixa_tool.rb          # Inserção de módulos
│   ├── agregado_tool.rb       # Inserção de agregados
│   ├── editor_tool.rb         # Edição inline
│   ├── template_tool.rb       # Inserção de templates
│   ├── pecas_avulsas_tool.rb  # Inserção de peças
│   ├── ambiente_tool.rb       # [NOVO] Desenho de ambiente
│   └── apresentacao_tool.rb   # [NOVO] Modo apresentação
│
├── ui/                        # Interface do usuário
│   ├── painel.rb              # Painel lateral principal
│   ├── propriedades.rb        # Painel de propriedades
│   ├── catalogo_templates.rb  # Catálogo de templates
│   ├── custo_painel.rb        # [NOVO] Painel de custo
│   ├── plano_corte_painel.rb  # [NOVO] Visual plano de corte
│   └── etiquetas_painel.rb    # [NOVO] Config de etiquetas
│
├── data/                      # [NOVO] Dados estáticos
│   ├── ferragens/             # Catálogo de ferragens
│   ├── materiais/             # Catálogo de materiais
│   ├── eletrodomesticos/      # Biblioteca de eletros
│   ├── templates/             # Templates de ambiente
│   └── temas/                 # Temas de acabamento
│
└── system/                    # Sistema
    ├── toolbar.rb
    ├── menu.rb
    └── observers.rb
```

### 4.2 Fluxo de Trabalho Ideal

```
1. DEFINIR AMBIENTE
   └─ Desenhar paredes OU escolher template pronto
       └─ Ex: "Cozinha em L, 3.20m x 2.40m, pé-direito 2.70m"

2. INSERIR MÓDULOS
   └─ Template auto-insere OU manual módulo a módulo
       └─ Snap automático entre módulos
       └─ Validação em tempo real (alertas visuais)
       └─ Custo atualizado a cada adição

3. CONFIGURAR COMPONENTES
   └─ Portas: tipo + puxador (auto-sugere baseado no estilo)
   └─ Gavetas: tipo + corrediça (auto-sugere baseado no peso)
   └─ Prateleiras: quantidade + posição
   └─ Ferragens: AUTO-SELECIONADAS (projetista só confirma)
   └─ Fita de borda: AUTO-APLICADA por regras de visibilidade

4. INSERIR ELETRODOMÉSTICOS
   └─ Escolhe cooktop → recorte automático no tampo
   └─ Escolhe forno → nicho com ventilação automática
   └─ Escolhe cuba → recorte automático no tampo

5. APLICAR ACABAMENTO
   └─ Tema global OU peça a peça
   └─ Preview em tempo real

6. REVISAR
   └─ Motor de validação roda automaticamente
   └─ Corrige alertas vermelhos (erros)
   └─ Avalia alertas amarelos (avisos)

7. APRESENTAR AO CLIENTE
   └─ Modo apresentação (esconde construção)
   └─ Preço total visível
   └─ Exporta PDF com vistas

8. PRODUZIR
   └─ Plano de corte otimizado (local)
   └─ Etiquetas de cada peça (local)
   └─ Lista de ferragens (local)
   └─ G-code se CNC disponível (local)
   └─ Integração ERP Ornato (opcional)
```

---

## PARTE 5 — PRIORIZAÇÃO (ROADMAP)

### Fase 1: MVP (Replicar UpMobb — 4-6 semanas)
> Fazer o que o UpMobb faz, localmente.

- [ ] Motor de caixa paramétrico (5 tipos: balcão, aéreo, torre, canto, mesa)
- [ ] Agregados internos (portas, gavetas, prateleiras, divisórias, fundos)
- [ ] Sistema de trocas (dobradiças, fixação, fundos, portas)
- [ ] Cores/acabamentos (catálogo de materiais e fitas)
- [ ] Alinhamento/snap entre módulos
- [ ] Peças avulsas
- [ ] Export JSON com usinagens e fitas
- [ ] Camadas (toggle peças, portas, ferragens, guias)
- [ ] Painel lateral com Configurador

### Fase 2: Diferenciação (Superar UpMobb — 4-6 semanas)
> Fazer o que o UpMobb NÃO faz.

- [ ] Fita de borda automática por regras de visibilidade
- [ ] Motor de validação (regras de engenharia)
- [ ] Motor de inteligência (auto-seleção de ferragem)
- [ ] Plano de corte local com visualização
- [ ] Etiquetas locais com código de barras
- [ ] Lista de materiais (BOM) com quantidades
- [ ] Precificação em tempo real (integração ERP)

### Fase 3: Excelência (Liderança de mercado — 4-6 semanas)
> O que ninguém no Brasil faz hoje.

- [ ] Templates de ambiente (cozinha, dormitório, banheiro)
- [ ] Motor de ambiente (desenho de paredes + auto-posicionamento)
- [ ] Biblioteca de eletrodomésticos com recortes automáticos
- [ ] Temas de acabamento (1 clique = projeto inteiro estilizado)
- [ ] Modo apresentação para cliente
- [ ] Export multi-formato (JSON, DXF, PDF, G-code)
- [ ] G-code local para CNC

### Fase 4: Escala (Ecossistema — ongoing)
> Criar um ecossistema completo.

- [ ] Integração completa ERP Ornato (pedidos, estoque, expedição)
- [ ] App mobile para acompanhamento da produção
- [ ] Marketplace de templates (projetistas vendem templates)
- [ ] Catálogo de ferragens atualizado por fornecedores
- [ ] Módulo de treinamento interativo dentro do plugin

---

## PARTE 6 — COMPARATIVO FINAL

| Feature | UpMobb | Ornato (Planejado) |
|---------|--------|-------------------|
| Modelagem paramétrica | ✅ | ✅ |
| Agregados (portas, gavetas, etc.) | ✅ | ✅ |
| Trocas de componentes | ✅ | ✅ (simplificado) |
| Cores/acabamentos | ✅ | ✅ |
| Alinhamento módulos | ✅ | ✅ |
| Export JSON | ✅ | ✅ |
| Templates de ambiente | ❌ | ✅ 🚀 |
| Seleção auto de ferragem | ❌ | ✅ 🚀 |
| Validação de engenharia | ❌ | ✅ 🚀 |
| Plano de corte local | ❌ | ✅ 🚀 |
| Etiquetas locais | ❌ | ✅ 🚀 |
| Precificação tempo real | ❌ | ✅ 🚀 |
| Biblioteca eletrodomésticos | ❌ | ✅ 🚀 |
| Temas de acabamento | ❌ | ✅ 🚀 |
| Modo apresentação cliente | ❌ | ✅ 🚀 |
| Fita de borda automática | ❌ | ✅ 🚀 |
| Funciona 100% offline | ❌ | ✅ 🚀 |
| Integração ERP próprio | ❌ | ✅ 🚀 |
| G-code local | ❌ | ✅ 🚀 |
| Sem mensalidade de plataforma | ❌ | ✅ 🚀 |

---

> **Conclusão**: O UpMobb é um bom modelador 3D, mas é apenas a "casca".
> Toda inteligência está na nuvem deles. O Ornato deve ser o cérebro completo:
> modela, valida, precifica, otimiza corte, gera etiquetas e G-code.
> Tudo local. Tudo integrado. Tudo sem depender de terceiros.

---

---

## PARTE 7 — MODELO HIBRIDO (Decisao do Victor — 28/02/2026)

> Victor: "eu gosto desse modelo" (referindo-se ao fluxo Plugin → JSON → Web)

### 7.1 Decisao Arquitetural

Apos explorar a plataforma web UpMobb (app.upmobb.net), Victor decidiu adotar
o **modelo hibrido**: Plugin faz modelagem, exporta JSON, plataforma web faz
otimizacao/producao.

```
┌─────────────────────────────────────┐
│   PLUGIN ORNATO (SketchUp)           │
│                                       │
│ • Modelagem parametrica               │
│ • Inteligencia de ferragem            │
│ • Validacao de engenharia             │
│ • Precificacao em tempo real          │
│ • Export JSON (compativel UpMobb)      │
│                                       │
│ STATUS: ✅ 29 arquivos, 17 engines    │
│         v0.3.0 (motor_export pronto)  │
└──────────────┬────────────────────────┘
               │ JSON
               ▼
┌─────────────────────────────────────┐
│   PLATAFORMA WEB ORNATO (a construir)│
│                                       │
│ • Importar JSON do plugin             │
│ • Otimizador plano de corte (nesting) │
│ • Geracao G-code CNC (.nc)            │
│ • Editor de etiquetas (customizavel)  │
│ • Armazem de materiais                │
│ • Controle de sobras                  │
│ • Lotes de producao                   │
│ • Configuracoes CNC/otimizador        │
│                                       │
│ STATUS: 🔲 A construir               │
└──────────────┬────────────────────────┘
               │ APIs
               ▼
┌─────────────────────────────────────┐
│   ERP ORNATO (existente — Express)    │
│                                       │
│ • Orcamentos                          │
│ • Estoque                             │
│ • Clientes                            │
│ • Financeiro                          │
│ • Expedição                           │
│                                       │
│ STATUS: ✅ Existente (port 3001)      │
└───────────────────────────────────────┘
```

### 7.2 Vantagens do Modelo Hibrido

1. **Plugin leve** — SketchUp nao precisa processar nesting/G-code
2. **Web acessivel** — qualquer navegador acessa producao
3. **Multi-usuario** — projetista modela, marceneiro ve producao
4. **Atualizavel** — web atualiza sem reinstalar plugin
5. **Compativel** — JSON funciona com UpMobb tambem (migração facil)

### 7.3 O que o Plugin JA faz (v0.3.0)

| Engine | Funcao | Linhas |
|---|---|---|
| motor_caixa | Caixa parametrica | ~280 |
| motor_agregados | Porta/gaveta/prat/div | ~820 |
| motor_portas | 9 tipos + dobradicas | ~600 |
| motor_furacao | Minifix/cavilha/system32 | ~260 |
| motor_fita_borda | 4 lados automatico | ~400 |
| motor_usinagem | Canal/rebaixo/rasgo/gola | ~900 |
| motor_pecas_avulsas | Pecas independentes | ~400 |
| motor_plano_corte | FFD + esquadrejadeira | ~380 |
| motor_templates | 20+ modelos, 6 ambientes | ~360 |
| motor_precificacao | Custo em tempo real | ~240 |
| motor_alinhamento | Snap entre modulos | ~190 |
| motor_inteligencia | Auto-ferragem | ~870 |
| motor_validacao | Regras engenharia | ~940 |
| motor_etiquetas | Etiquetas producao | ~1010 |
| motor_ficha_tecnica | Ficha tecnica completa | ~1340 |
| motor_cotagem | Cotagem 3D automatica | ~520 |
| motor_export | JSON compativel UpMobb | ~1100 |
| **TOTAL** | **17 engines** | **~10.610** |

### 7.4 Proximos Passos

**Imediato (Plugin)**:
1. Testar motor_export no SketchUp com modulo real
2. Importar JSON gerado no UpMobb para validar compatibilidade
3. Ajustar mapeamentos se necessário

**Curto prazo (Web Platform)**:
1. Criar importador JSON na plataforma web Ornato
2. Implementar listagem de pecas (22 colunas)
3. Implementar otimizador de plano de corte
4. Implementar geracao de etiquetas

**Medio prazo (Producao)**:
1. Magazine de ferramentas CNC
2. Geracao G-code (.nc)
3. Armazem de materiais + controle de sobras
4. Integracao com ERP existente

---

*Planejamento criado em 28/02/2026*
*Baseado na análise completa do UpMobb V2.10.22*
*Atualizado com exploracao da plataforma web UpMobb e decisao de modelo hibrido em 28/02/2026*
*Para implementação no Plugin Ornato SketchUp + Plataforma Web*
