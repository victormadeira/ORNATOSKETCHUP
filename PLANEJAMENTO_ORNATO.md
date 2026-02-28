# Planejamento Estratégico — Plugin Ornato SketchUp
# Análise Crítica do UpMobb + Proposta de Sistema Superior

> Documento gerado em 28/02/2026
> Baseado na análise completa do UpMobb V2.10.22
> Objetivo: Criar o melhor plugin de marcenaria paramétrica do Brasil

---

## PARTE 1 — FALHAS E LIMITAÇÕES DO UPMOBB

### 1.1 Dependência Total da Nuvem

**Problema crítico**: O UpMobb é apenas um modelador 3D. TODO processamento
inteligente (plano de corte, G-code, etiquetas, orçamento) depende de upload
para a plataforma online deles.

**Impacto**:
- Sem internet = sem produção
- Dados do cliente ficam nos servidores deles
- Custo mensal/anual atrelado à plataforma
- Impossível funcionar offline em fábricas sem internet estável
- Vendor lock-in (preso ao ecossistema UpMobb)

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

*Planejamento criado em 28/02/2026*
*Baseado na análise completa do UpMobb V2.10.22*
*Para implementação no Plugin Ornato SketchUp*
