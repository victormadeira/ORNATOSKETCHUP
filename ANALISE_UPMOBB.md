# Analise Completa do Plugin UpMobb V2.10.22
# Para Replicacao no Plugin Ornato

> Investigacao realizada via Chrome Remote Desktop em 28/02/2026
> SketchUp 2024 com UpMobb V2.10.22 instalado

---

## 1. VISAO GERAL DA INTERFACE

O UpMobb funciona como um **painel lateral (HtmlDialog)** dentro do SketchUp, com:
- **Barra lateral esquerda** com 14 icones de navegacao
- **Area de conteudo central** que muda conforme o icone selecionado
- **2 toolbars flutuantes** no viewport do SketchUp
- **Toggle "Estou revisando"** no rodape (ativa modo revisao)
- **Versao** exibida no rodape (V2.10.22)

---

## 2. BARRA LATERAL — 14 ICONES (Mapeamento Completo)

### 2.1 Menu (Hamburger) — Tela Inicial
- **Detalhes do projeto**: nome do cliente, projetista, descricao do projeto
  - Botoes: Excluir (vermelho), Visualizar (olho), Editar (azul)
- **Meus dados**: dados cadastrais do usuario
  - Botoes: Codigo, Visualizar, Editar

### 2.2 Biblioteca de Modulos Prontos (Casa/Home)
- **Funcao**: Templates/atalhos salvos pelo usuario para reutilizacao rapida
- **Ambientes**: Cozinha, Quarto, Banheiro, Lavanderia, Escritorio
- **Busca**: Campo "Pesquise por component"
- **Tipos por ambiente**: Ex: Cozinha > Balcao
- **Comportamento**: Ao clicar no modulo, ele e inserido diretamente na cena 3D
- **Posicionamento**: Setas direcionais (cima, baixo, esquerda, direita) aparecem apos insercao

### 2.3 Construtor (Pessoa/Builder)
- **Funcao**: Catalogo principal de componentes para construcao de moveis
- **Info**: "Modulos que vem direto para a cena"
- **Navegacao**: Breadcrumb (Construtor > Caixas > Balcao)

#### Grupos do Construtor:
1. **Acessorios e Ferragens** — ferragens, puxadores, corredicoas
2. **Caixas** — carcacas de moveis (PRINCIPAL)
   - **Armario Aereo** — modulos superiores/parede
   - **Armario Alto** — modulos torre/coluna
   - **Balcao** — modulos inferiores/base (16 tipos!)
     - Canto Aberto
     - Canto Aberto com Fechamento
     - Canto Aberto com Tampo
     - Canto Direito (cego)
     - Canto Direito com Tampo
     - Canto Esquerdo
     - Canto Esquerdo com Tampo
     - Canto Obliquo
     - Canto Obliquo com Tampo
     - Linear (um vao)
     - Linear com Lateral Passante
     - Linear com Tampo
     - Linear com Tampo e Lateral Passante
     - Linear Encaixe 45 graus
     - Linear Laterais com Rasgo
     - Linear Modular com Troca
   - **Mesas** — mesas e bancadas
   - **Outras Caixas** — tipos especiais
3. **Componentes** — componentes avulsos
4. **Decoracao** — itens decorativos
5. **Metais e Estruturas** — perfis metalicos, estruturas
6. **Modulos Prontos** — modulos completos pre-configurados
7. **Outros itens** — itens diversos
8. **Paineis** — paineis avulsos
9. **Pecas** — pecas de corte individuais
10. **Portas de Passagem** — portas de ambientes
11. **Usinagens** — operacoes CNC
12. **Vidros e Espelhos** — vidros e espelhos

#### Cada modulo tem:
- **Thumbnail** com preview 3D
- **Nome** descritivo
- **Icone engrenagem** (configuracao do modulo)
- **Click para inserir** na cena

### 2.4 Agregados (Seta/Import)
- **Funcao**: Modulos para inserir DENTRO de outros modulos
- **Info**: "Modulos para inserir em outros"
- **Conceito**: Seleciona um modulo na cena e depois escolhe o agregado para adicionar

#### Grupos de Agregados (10 categorias):

**1. Internos** (19 sub-grupos — o mais extenso):
   - Acessorios
   - Cabideiros (varao de roupas)
   - Caixas de afastamento (espacadores)
   - Divisoes Invisiveis
   - Divisorias (verticais)
   - Divisorias Compostas
   - Espelhos e vidros
   - Fechamentos (paineis de fechamento)
   - Fixacao (minifix, confirmat, etc.)
   - Fundos (paineis traseiros)
   - Gavetas
   - Painel com Recorte
   - Porta Basculante (flip-up)
   - Porta dupla
   - Porta Temperos (porta especial)
   - Portas (simples)
   - Prateleira com Recorte de Canto
   - Prateleiras
   - Prateleiras Compostas

**2. Para Gavetas** — corredicoas e componentes de gaveta

**3. Para Peca** — agregados para pecas avulsas

**4. Inferiores** — agregados especificos para modulos inferiores

**5. Para Portas** — PUXADORES (12 tipos!):
   - Desempenadores
   - Puxadores Aba
   - Puxadores Aba Porta de correr
   - Puxadores Alca
   - Puxadores Alca Porta de correr
   - Puxadores Concha
   - Puxadores Concha Porta de Correr
   - Puxadores Gangorra
   - Puxadores Gangorra Porta de Correr
   - Puxadores Genericos
   - Puxadores Ponto
   - Puxadores Ponto Porta de Correr

**6. Externos** — agregados externos ao modulo

**7. Superiores** — agregados para modulos superiores

**8. Portas de correr** — sistemas de portas deslizantes

**9. Para Paineis** — agregados para paineis

**10. Para Frentes de Gaveta** — frentes de gaveta

### 2.5 Trocas (Target/Alvo)
- **Funcao**: Trocar componentes de um modulo selecionado
- **Info**: "Modulos para realizar trocas"
- **Conceito**: Seleciona modulo > troca ferragem de fixacao, estilo do movel, tipo de fundo, etc.

#### Grupos de Trocas (11 grupos — mapeamento completo):

**1. Caixas** — Troca o modelo estrutural da carcaça (18+ modelos):
- Cada modelo representa uma configuração diferente: com/sem fundo, com/sem divisória,
  com lateral passante ou base passante, abertura frontal variada
- Modelos numerados: modelo 01 ao 18+ (nomenclatura simples sem descritivo)
- Seleção visual por thumbnail 3D

**2. Divisorias Especiais** — 2 tipos:
- Com recorte perfil Cava Alternativa 2322
- Divisoria normal

**3. Dobradiças** — 9+ tipos (marcas: Blum, Hettich, Hardt, HD):
- Blum blumotion top
- Blum Clip Stand
- Blum sem mola (fecho toque)
- Dobradiça 35mm calço 3D com amortecedor HETTICH
- Dobradiça 35mm calço 4F HARDT
- Dobradiça 35mm calço fixo 4F com amortecedor HARDT
- Dobradiça 35mm com amortecedor calço 3D HARDT
- Dobradiça 35mm Push Open 2F HARDT
- Dobradiça com amortecedor canto cego 90° HD
- Dobradiça Generica

**4. Fixação Divisoria** — Kits de ferragem para fixar divisórias:
- Chapa Fixação fundos
- Kit Cavilha Para Face
- Kit Cavilhas
- Kit com 1 Minifix pino Twister e 1 Cavilha
- Kit Minifix com Cavilha pino Rapid
- Kit Minifix com Cavilha pino Twister
- Kit Minifix Haste Dupla com Cavilha
- Kit Minifix pino Rapid
- Kit Minifix pino Twister
- Kit Parafuso
- Kit Parafuso com Cavilha
- Kit Parafuso Para Face

**5. Fixação Lateral** — mesmo catálogo de kits da Fixação Divisoria

**6. Fixação Prateleira** — mesmos kits + item exclusivo:
- **Conector Oculto Bigfer** (suporte de prateleira oculto, exclusivo desta categoria)

**7. Fixação Régua Deitada** — mesmo catálogo de kits

**8. Fundos** — 4 tipos de painel traseiro:
- Fundo Horizontal
- Fundo Horizontal com rasgo
- Fundo Vertical (padrão)
- Fundo Vertical com rasgo

**9. Portas de Giro** — 29 tipos (maior catálogo):
- *Perfis Alumínio (AL) — Renzex/Alternativa*:
  AL Perfil 1007-1107 Renzex, AL Perfil 1130-1131 Renzex, AL Perfil 903-905 Renzex,
  AL Perfil 918-919 Renzex, AL Perfil Arezzo Alternativa, AL Perfil Cava Fita,
  AL Perfil Integrato Contatto, Perfil 4023-4025 Alternativa, Perfil Cava 4030T Alternativa
- *MDF — Cava*:
  Cava MDF, Cava MDF 45°, Cava MDF Simples, Cava Quadrada
- *MDF — Chanfrada / Especial*:
  Chanfrada Palhinha, Chanfrada Rebaixo Central, Chanfrada Tela Metalica, Espelho Colado
- *MDF — Perfis (versão MDF dos perfis alumínio)*:
  Perfil 1007-1107, Perfil 1130-1131 Renzex, Perfil 903-905 Renzex, Perfil 918-919 Renzex,
  Perfil Arezzo Alternativa, Perfil Cava Fita, Perfil Integrato Contatto
- *MDF — Provençal*:
  Provençal, Provençal Chanfro, Provençal Moldura 6mm, Provençal Moldura 6mm Reguas,
  Provençal Moldura 6mm Reguas 45°
- *Sem Puxador* (porta MDF lisa sem recorte de puxador)

**10. Portas Duplas** — mesmos tipos de Portas de Giro em versão dupla (2 folhas)
  (mesmos perfis AL Renzex/Alternativa e MDF)

**11. Régua Dianteira** — 2 tipos:
- Régua Dianteira Veio Horizontal
- Régua Dianteira Veio Vertical

### 2.6 Cores (Paleta)
- **Funcao**: Aplicar acabamentos/cores aos moveis
- **Info**: "Cores para aplicar as modulos"
- **Conceito**: Trocar acabamento de MDF, cor de fitas de borda, cor de componentes (cabideiro, etc.)

#### Tipos:
- **MDF** — cores/texturas de MDF disponiveis
- **Fitas de borda** — cores de fitas de borda
- **Componentes** — cores de componentes (puxadores, varoes, etc.)

#### Ferramentas extras no topo:
- Icone de alvo (selecionar onde aplicar)
- Icone de pincel (aplicar cor)
- Icone de setas (trocar direcao)

### 2.7 Orcamento (Documento/$)
- **Funcao**: Sistema de orcamento integrado (estilo ERP online)
- **Janela separada** que abre sobre o SketchUp

#### Recursos:
- **Toggle "Visualizar orcamento com meu markup"** — aplica margem de lucro
- **3 modos de selecao**:
  - Solicitar a central (envia para central da UpMobb)
  - Selecionados (apenas modulos selecionados)
  - Todo o projeto (projeto inteiro)
- **4 tipos de relatorio**:
  - Resumido — visao geral
  - Modulos — por modulo
  - Detalhado — detalhamento completo
  - Analitico — analise profunda
- **Campos do orcamento**: Meu Numero, Data, Cliente, Projeto, Projetista

### 2.8 Camadas (Diamante/Layers)
- **Funcao**: Gestao de visibilidade de camadas
- **Info**: "Ligar e desligar camadas de desenho relacionadas aos componentes do plugin"

#### Camadas com toggles ON/OFF:
- **UpAlert** — alertas visuais
- **UpFerragens** — ferragens (dobradicas, corredicoas)
- **UpGuias** — guias e medidas auxiliares
- **UpPecas** — pecas de corte
- **UpPortas** — portas e frentes
- **UpSelectorBox** — caixa de selecao (normalmente OFF)
- **UpTampas** — tampos e tampas

### 2.9 Alertas/Divergencias (Triangulo)
- **Funcao**: Verificar projeto para inconsistencias e erros
- **Requer**: Modo "Estou revisando" ativado (toggle no rodape)
- **Mensagem**: "Somente no modo revisao e possivel testar as divergencias do projeto"
- **Conceito**: Valida se modulos estao corretos, sem sobreposicoes, pecas faltantes, etc.

### 2.10 Exportacao (Upload/Share)
- **Funcao**: Exportar dados do projeto para producao e outros sistemas
- **Info**: "Listas de pecas, listas de compras, aplicacao de numeracao por modulos, inclusive gerar usinagens"

#### Exportar para outros sistemas:
- **UpMobb** — exportar para plataforma UpMobb
- **SIS Marcenaria** — exportar para SIS Marcenaria (formato JSON)

#### Exportar listagens:
- **Itens a comprar** — lista de compras completa
- **Vidros e espelhos** — lista especifica
- **Perfis e lineares** — perfis de aluminio, etc.
- **Componentes a conferir** — checklist de componentes

#### Informacoes de producao:
- **Listagem de pecas** (com configuracao avancada)
- **Imagem de peca** — foto individual de cada peca
- **Etiqueta completa** — etiqueta com todos os dados
- **Etiqueta peca composta** — para pecas montadas
- **Etiqueta porta de aluminio** — especifica para portas de aluminio
- **Arquivos de usinagem** (com configuracao) — GERA ARQUIVOS CNC!

#### Outros:
- Funcionalidades adicionais de exportacao

### 2.11 Preferencias (Engrenagem/Settings)
- **Funcao**: Configuracoes gerais do plugin
- **Info**: "Ajustar parametros de configuracoes para seus projetos, como espessura padrao do MDF"

#### Projeto e usabilidade:
- **Padroes de painel** — espessura padrao do MDF, dimensoes padrao
- **Visualizacao da biblioteca** — como exibir modulos na biblioteca
- **Inserir agregados 1 click** — modo rapido de insercao
- **Configurador** — configuracao avancada

#### Exportacao:
- Configuracoes de exportacao (formatos, caminhos, etc.)

#### Outros:
- Configuracoes diversas

### 2.12 Render IA (Estrelas/Sparkles)
- **Funcao**: Renderizacao por Inteligencia Artificial
- **Info**: "Configurar preferencias de render por AI e exportar as imagens geradas"

#### Recursos:
- **Preview** da cena atual
- **Dimensoes**: Altura e Largura configuraveis (ex: 794 x 1920)
- **Resolucoes alternativas**: personalizado ou presets
- **Cenas do modelo**: selecionar cena para renderizar
- **Colecao de imagens do projeto**: galeria de renders gerados

### 2.13 Atualizar (Refresh)
- **Funcao**: Atualizar/sincronizar listas e dados do plugin
- **Resultado**: "Listas atualizadas!"

### 2.14 Sair (Seta para direita)
- **Funcao**: Logout/sair do plugin

---

## 3. TOOLBARS FLUTUANTES NO VIEWPORT

### 3.1 Toolbar Principal "UpMobb" (~10 icones)
Da esquerda para direita:
1. **Engrenagem** — Configuracao do modulo selecionado (ABRE MENU DE CONFIGURACOES COMPLETO)
2. **Mira Verde** — Selecionar componente
3. **Mira Amarela/Ciano** — Selecionar componente especifico
4. **Mira Vermelha** — Excluir peca
5. **Fantasma** — Modo fantasma/transparencia (?)
6. **Vinculos (2 icones)** — Vincular/desvincular componentes
7. **Barras horizontais** — Lista/menu de opcoes
8. **Construcao** — Modo construcao
9. **Mao/Click** — Ferramenta de selecao por click

### 3.2 Toolbar "UpMobb Assiste..." (4 icones)
1. **Lupa com formas** — Buscar componente
2. **Caminhao** — Entrega/logistica (?)
3. **Grade/Tabela** — Lista/relatorio
4. **Triangulo/Vista** — Renderizacao/vista

---

## 4. FUNCIONALIDADES-CHAVE PARA REPLICAR NO ORNATO

### 4.1 Sistema de Construcao Parametrica
- Modulos base (caixas) com 16+ tipos de balcao
- Cada modulo tem thumbnail 3D + engrenagem de configuracao
- Insercao direta na cena com posicionamento por setas
- Sistema hierarquico: Grupo > Sub-grupo > Modulo

### 4.2 Sistema de Agregados (Fundamental!)
- Agregados sao inseridos DENTRO de modulos existentes
- 10 categorias com 50+ sub-categorias
- Internos: gavetas, prateleiras, divisorias, portas, fundos, cabideiros...
- Para Portas: 12 tipos de puxadores
- Para Gavetas: corredicoas e sistemas
- Externos, Superiores, Inferiores, Portas de correr
- **"Inserir agregados 1 click"** como preferencia

### 4.3 Sistema de Trocas
- Trocar ferragem de fixacao (minifix, confirmat, etc.)
- Trocar estilo do movel
- Trocar tipo de fundo
- Trocar fixacao (lateral, regua deitada, etc.)

### 4.4 Sistema de Cores/Acabamentos
- Aplicar cores/texturas MDF ao modulo
- Trocar fitas de borda por lateral
- Trocar cores de componentes (cabideiro, puxador, etc.)

### 4.5 Sistema de Orcamento
- Orcamento online integrado (estilo ERP)
- Markup configuravel
- 4 tipos de relatorio (Resumido, Modulos, Detalhado, Analitico)
- 3 escopos (central, selecionados, projeto inteiro)
- Dados do cliente/projeto

### 4.6 Sistema de Exportacao
- JSON para outros sistemas (UpMobb, SIS Marcenaria)
- Listas de compras
- Listas especificas (vidros, perfis, componentes)
- Listagem de pecas para producao
- Etiquetas (completa, composta, aluminio)
- **Arquivos de usinagem CNC** (MUITO IMPORTANTE)

### 4.7 Sistema de Camadas
- Visibilidade por tipo: ferragens, guias, pecas, portas, tampas, alertas
- Toggle individual ON/OFF

### 4.8 Validacao/Alertas
- Modo revisao para verificar divergencias
- Detecta inconsistencias no projeto

### 4.9 Biblioteca de Templates
- Salvar modulos como templates reutilizaveis
- Organizar por ambiente (Cozinha, Quarto, etc.)
- Busca por componente

### 4.10 Render por IA
- Renderizacao AI dos projetos
- Configuracao de dimensoes e resolucao
- Selecao de cenas
- Galeria de imagens geradas

### 4.11 Ferramentas de Selecao (Miras)
- **Mira Verde**: Selecionar componente (para editar/configurar)
- **Mira Ciano/Amarela**: Selecionar componente especifico (sub-selecao)
- **Mira Vermelha**: Excluir peca

---

## 5. FLUXO DE TRABALHO TIPICO NO UPMOBB

1. **Configurar projeto** (Menu > Detalhes do projeto)
2. **Inserir modulo** via Construtor (Caixas > Balcao > Linear)
3. **Posicionar** usando setas direcionais
4. **Adicionar agregados** (Agregados > Internos > Prateleiras, Gavetas, Portas...)
5. **Configurar modulo** (engrenagem na toolbar — abre menu de configuracoes detalhado)
6. **Trocar componentes** (Trocas > ferragem, estilo, fundo...)
7. **Aplicar cores** (Cores > MDF, Fitas de borda, Componentes)
8. **Validar** (Alertas — verificar divergencias no modo revisao)
9. **Gerar orcamento** (Orcamento > selecionar tipo de relatorio)
10. **Exportar** (Exportacao > listagens, producao, CNC, JSON)
11. **Render** (Render IA para apresentacao ao cliente)

---

## 6. COMPARACAO UPMOBB vs ORNATO (Status Atual)

| Funcionalidade | UpMobb | Ornato |
|---|---|---|
| Painel lateral HtmlDialog | Sim | Sim (painel.rb) |
| Construtor de modulos | 12 grupos, 50+ modulos | motor_caixa.rb (basico) |
| Tipos de balcao | 16 tipos | ~5 tipos |
| Agregados | 10 categorias, 50+ sub | motor_agregados.rb (5 tipos) |
| Puxadores | 12 tipos | Nao implementado |
| Trocas de componentes | 5 grupos | Nao implementado |
| Cores/acabamentos | MDF + Fitas + Componentes | Parcial (material_info.rb) |
| Orcamento | Online com 4 relatorios | motor_precificacao.rb |
| Camadas | 7 camadas toggleaveis | Nao implementado |
| Alertas/Validacao | Modo revisao | Nao implementado |
| Exportacao sistemas | 2 sistemas | API REST (planejado) |
| Exportacao listagens | 4 tipos de lista | motor_plano_corte.rb |
| Producao | Pecas + Etiquetas + CNC | motor_usinagem.rb |
| Templates/Biblioteca | Por ambiente com busca | motor_templates.rb |
| Render IA | Sim | Nao planejado |
| Miras de selecao | 3 tipos (verde/ciano/vermelha) | editor_tool.rb |
| Toolbars flutuantes | 2 toolbars | toolbar.rb |
| Menu suspenso config | Sim | Nao implementado |

---

## 7. PRIORIDADES PARA IMPLEMENTACAO NO ORNATO

### Alta Prioridade (Core):
1. **Expandir tipos de caixas** — de 5 para 16+ tipos de balcao
2. **Sistema de agregados completo** — todas as 10 categorias
3. **Menu de configuracao do modulo** (engrenagem) — dialog completo
4. **Sistema de trocas** — trocar ferragem, estilo, fundo
5. **Sistema de cores/acabamentos** — aplicar materiais visualmente
6. **Exportacao CNC** — arquivos de usinagem

### Media Prioridade (Producao):
7. **Camadas de visibilidade** — toggles por tipo de componente
8. **Validacao/alertas** — verificar divergencias
9. **Etiquetas de producao** — completa, composta, aluminio
10. **Exportacao JSON** — para sistemas externos
11. **Puxadores** — 12 tipos de puxadores

### Baixa Prioridade (Nice-to-have):
12. **Render IA** — renderizacao por AI
13. **Orcamento online** — integracao com central
14. **Menu suspenso** para selecao de componentes
15. **Miras coloridas** — verde/ciano/vermelha

---

## 8. DETALHES TECNICOS OBSERVADOS

### Arquitetura:
- Plugin roda como HtmlDialog dentro do SketchUp
- Comunicacao bidirecional entre Ruby (backend) e HTML/JS (frontend)
- Dados do modulo armazenados como atributos no Group do SketchUp
- Sistema de camadas usa Layers/Tags do SketchUp
- Toolbars flutuantes sao UI::Toolbar nativas do SketchUp

### Performance:
- Interface responsiva e fluida
- Thumbnails 3D pre-renderizados para catalogo
- Insercao de modulos e quase instantanea
- Toolbars sao compactas e nao bloqueiam o viewport

### UX/Design:
- Cor principal: azul (#0d6efd ou similar)
- Cards com thumbnail + nome + botoes
- Breadcrumb para navegacao hierarquica
- Icones claros e intuitivos
- Secoes colapsaveis (accordion)
- Toggles ON/OFF para camadas
- Busca por componente

---

## 9. VISITA GUIADA — DETALHES DO CONFIGURADOR (Sessao com Victor)

### 9.1 Configurador do Modulo (Engrenagem na Toolbar)
Ao selecionar um modulo com a mira verde, abre uma **janela "Configurador"** com:

**Barra lateral esquerda** (abas do configurador):
1. Puzzle — Componente/agregado
2. Dimensoes — medidas editaveis (PRINCIPAL)
3. Grid/posicoes — distribuicao
4. Olho — visibilidade
5. Corrente cortada — desvincular
6. Gota — acabamento/cor
7. Lista/check — propriedades
8. Tesoura — cortar/modificar
9. Seta — voltar/desfazer

**Barra superior** (acoes):
- Puzzle vermelho (remover) / Puzzle verde (adicionar)
- Copiar/duplicar
- Grafico/analytics
- Rotacao / Aplicar

**Para Balcao — campos editaveis:**
- Elevacao: -15.50
- Comprimento: 900.00
- Profundidade: 570.00
- Altura: 710.00
- Afastamento Traseiro em relacao ao fundo: 22.50
- Espessura: 15mm (dropdown)
- Tipo de montagem: Base passante (dropdown)
- Botao "Aplicar"
- Cada campo tem icone vermelho para resetar ao padrao

**IMPORTANTE**: O Configurador e CONTEXTUAL — mostra campos diferentes para cada tipo de modulo:
- Balcao: elevacao, comprimento, altura, afastamento traseiro
- Paineis: dimensoes basicas
- Paineis ripados: dimensoes + tamanho de ripas + espacamento de ripas
- Porta dupla: folga entre portas, transpasses, posicao puxador
- Cada tipo mostra apenas parametros relevantes

### 9.2 Mira Ciano — Selecao de Peca Individual
Ao usar a mira ciano/verde, seleciona uma **peca especifica** dentro do modulo.
O Configurador muda para modo "Peca" (indicado no rodape) mostrando:

**Exemplo — Regua Deitada selecionada:**
- Nome: Regua Deitada
- Tipo: Regua
- Descricao: Regua Deitada 15.5 mm
- Material: MDF
- Acabamento: Branco Tx, Laminacao 2C
- Dimensoes: Comprimento 869mm, Largura 70mm

**Opcoes editaveis da peca:**
- Adicionar ao comprimento (+/-): ajuste fino
- Adicionar a altura (+/-): ajuste fino
- Mover em X (+/-): reposicionar
- Mover em Y (+/-): reposicionar
- Botao "Aplicar"

### 9.3 Mira Vermelha — Exclusao de Peca
- Peca selecionada fica **VERMELHA** no viewport
- Label aparece (ex: "Conjunto fixacao")
- Confirma e a peca e excluida do modulo
- Util para: remover fundo, remover regua, trocar porta errada

### 9.4 Fluxo de Insercao de Agregados (Portas)
Navegacao: Agregados > Internos > Portas

**Tipos de porta disponveis:**
- Chanfrada Palhinha (MDF Provencal com palhinha/rattan)
- Chanfrada Rebaixo Central (MDF Provencal com rebaixo)
- Chanfrada Tela Metalica (MDF Provencal com tela)
- Espelho Colado (MDF com espelho)
- Renzex (MDF com perfil Renzex — 2 variacoes)
- E mais...

**Tipos de porta dupla:**
- Cava MDF 45 graus
- Cava MDF Simples
- Cava Quadrada
- Chanfrada Palhinha
- Chanfrada Rebaixo
- Chanfrada Tela Metalica
- E mais...

**Fluxo de insercao:**
1. Escolhe tipo de porta no catalogo
2. Aparece mira azul no viewport
3. Clica no modulo alvo
4. Aperta Enter → porta inserida!
5. "Caminhos possiveis: 0/3" mostra vaos disponiveis

**Configurador da Porta Dupla inserida:**
- Nome: Conjunto Porta Dupla
- Tipo: Porta de giro cava MDF 45
- Material: Branco Tx
- Comprimento CavaMDF (0 = total)
- Posicao do puxador: Cima (dropdown)
- Espessura: 15mm
- Folga entre portas: 3.50
- Transpasse inferior: 12.00
- Transpasse superior: 12.00
- Tipo de dobradica (abaixo)

**Validacao automatica:**
- Se porta simples e grande demais para o vao → aparece alerta ⚠️
- Sistema avisa que deveria ser porta dupla

### 9.5 Niveis de Selecao
O rodape do Configurador indica o nivel:
- **"Componente"** → modulo inteiro selecionado
- **"Peca"** → peca individual selecionada

---

## 10. NOTAS DO USUARIO (Victor)

- "Biblioteca sao modulos prontos que o usuario salvou, uma especie de atalho"
- "Ao clicar num modulo, voce pode inserir agregados neles, selecionando portas etc"
- "Troca de componentes funciona ao selecionar um modulo, trocar ferragem de fixacao, trocar estilo do movel"
- "Aplicar cores serve para trocar acabamentos de moveis, fitas de bordas de laterais, componentes como cabideiro"
- "Orcamento e feito online, seleciona estilo do movel e faz orcamento em algo semelhante a nossa ERP"
- "Existe menu suspenso para selecionar componentes para modificacoes"
- "Mira verde = selecionar componente, mira ciano = selecionar um componente, mira vermelha = excluir peca"
- "La abre um menu de configuracoes do modulo muito interessante"
- "Exportar funciona para exportar JSON para orcamento em outras plataformas ou exportar para fazer o plano de corte"
- "Nessa funcao voce consegue configurar toda a caixaria"
- "Tudo que for conveniente para aquele tipo de modulo e mostrado"
- "Paineis ripados tem dimensoes, tamanho de ripas, espacamento de ripas"
- "Seta ciano seleciona peca especifica para edicao — adicionar comprimento, altura, mover"
- "Seta vermelha seleciona e fica vermelha a peca, dai pode excluir unicamente a peca"
- "Seleciona porta, aperta Enter e ja era — modulo recebe a porta"
- "Aviso aparece quando porta e grande demais — deveria ter colocado porta dupla"
- "Existem muitas coisas nos agregados — portas de correr, tamponamento, etc."
- "Sistema e capaz de modelar tudo, capaz de editar tudo"

---

## 11. TIPOS DE DOBRADICA — Reta, Curva e Supercurva

O UpMobb permite configurar o tipo de dobradica no Configurador da porta (campo "Tipo de dobradica").
Existem 3 tipos principais, cada um para uma situacao de montagem diferente:

### 11.1 Dobradica Reta (Straight / Full Overlay)
- **Aplicacao**: Porta **sobreposta** — a porta cobre totalmente a lateral da caixa
- **Calco (cranking)**: 0mm — braco reto, sem curvatura
- **Abertura**: Limitada a ~95-100 graus
- **Quando usar**: Modulos com **uma unica porta** por lateral, onde a porta sobrepoe completamente a espessura da lateral
- **Resultado visual**: Quando fechada, a porta fica na frente da lateral, cobrindo-a totalmente
- **E a mais comum** em moveis residenciais simples

### 11.2 Dobradica Curva (Curved / Half Overlay / Semi-sobreposta)
- **Aplicacao**: Porta **semi-sobreposta** — a porta cobre parcialmente a lateral
- **Calco (cranking)**: ~9.5mm — braco com curvatura media
- **Abertura**: Maior que 100 graus
- **Quando usar**: Modulos com **duas portas adjacentes** que compartilham a mesma lateral central (ex: armario com 2 vaos lado a lado)
- **Resultado visual**: Cada porta cobre metade da espessura da lateral compartilhada
- **Essencial** para sequencias de portas em linha (cozinhas com modulos lado a lado)

### 11.3 Dobradica Supercurva (Super-curved / Inset / Embutida)
- **Aplicacao**: Porta **embutida** (porta de encaixe) — a porta fica rente/alinhada com a lateral
- **Calco (cranking)**: ~16mm — braco com curvatura maxima
- **Abertura**: Maior que 100 graus
- **Quando usar**: Quando a porta deve ficar **no mesmo plano** que as laterais do modulo (acabamento flush/embutido)
- **Resultado visual**: Quando fechada, a porta fica alinhada com a face da lateral — visual premium e clean
- **Mais sofisticada** — usada em moveis de alto padrao

### 11.4 Tabela Comparativa

| Caracteristica | Reta | Curva | Supercurva |
|---|---|---|---|
| Tipo de porta | Sobreposta | Semi-sobreposta | Embutida |
| Calco do braco | 0mm (reto) | ~9.5mm (medio) | ~16mm (maximo) |
| Sobreposicao | Total (~18mm) | Parcial (~9mm) | Nenhuma (0mm) |
| Angulo abertura | ~95-100° | ~100-110° | ~100-110° |
| Uso tipico | 1 porta por lateral | 2 portas na mesma lateral | Porta flush/embutida |
| Visual | Porta sobre lateral | Porta meia-lateral | Porta rente a lateral |
| Complexidade | Simples | Media | Alta |
| Preco | $ | $$ | $$$ |

### 11.5 Impacto no Calculo de Pecas (Ornato Plugin)

No motor de portas do Ornato (`motor_portas.rb`), o tipo de dobradica afeta:
1. **Largura da porta**: descontar sobreposicao conforme tipo
   - Reta: largura_vao + (2 × sobreposicao) — porta maior que o vao
   - Curva: largura_vao + sobreposicao — porta cobre metade da lateral
   - Supercurva: largura_vao - folga — porta menor que o vao (cabe dentro)
2. **Posicionamento**: offset da porta em relacao a lateral
3. **Furacao na lateral**: posicao dos furos de cup (35mm) varia conforme tipo
4. **Quantidade de dobradicas**: mesma regra (por altura), mas posicao X muda

---

## 12. SISTEMA DE GAVETAS — Detalhes Completos

### 12.1 Tipos de Gavetas (Agregados > Internos > Gavetas)

**Conjuntos pre-definidos por quantidade:**
- **Conjunto 1 und** — 1 gaveta (thumbnail: 1 gaveta)
- **Conjunto 2 und** — 2 gavetas empilhadas
- **Conjunto 3 und** — 3 gavetas empilhadas
- **Conjunto 4 und** — 4 gavetas empilhadas
- **Conjunto 5 und** — 5 gavetas empilhadas

**Gavetas Cofre (especiais):**
- **Gaveta Cofre Inferior (Basculante)** — cofre tipo flip-up
- **Gaveta Cofre (Frente Falsa)** — com frente decorativa
- **Gaveta Cofre (Gaveta Lateral)** — abertura lateral
- **Gaveta Cofre Inferior (Frente Falsa)** — combinacao
- **Gaveta Cofre Lateral** — abertura pela lateral

**Outros:**
- **Gaveta Multipla** — configuravel (quantidade variavel)

### 12.2 Fluxo de Insercao

Identico ao de Portas:
1. Clica no tipo de gaveta no catalogo
2. Aparece **mira azul** no viewport
3. Hover sobre modulo → modulo destaca em azul + "Caminhos possiveis: 0/3"
4. Clica no modulo alvo
5. Aperta **Enter** → gaveta inserida!

### 12.3 Configurador da Gaveta (apos insercao)

**Titulo**: "Conjunto de gavetas" / "Conjunto de gavetas 1 und"
**Secao Opcoes:**
- **Altura maxima corpo gaveta**: 0.00 (com botao reset vermelho)
- **Interno**: nao (dropdown)
- **Posicionar corpo em relacao a frente**: mesma posicao (dropdown)
- **Reducao contra frente**: 0.00
- **Transpasse inferior**: 12.00
- **Transpasse esquerdo**: 12.00
- **Transpasse direito**: 12.00
- **Transpasse superior**: 12.00
- Botao **Aplicar**
- Tabs: `mm` | `Componente`

### 12.4 Trocas Contextuais para Gaveta

Quando uma gaveta esta selecionada, o painel **Trocas** mostra automaticamente 7 grupos especificos:

1. **Corpo de Gaveta** — trocar o corpo/caixa da gaveta
2. **Corredicao Telescopica** — variantes de telescopica:
   - Corredicoa Generica (linha guia somente)
   - Corredicoa Telescopica Green Light
   - Corredicoa Telescopica Green Normal
   - Corredicoa Telescopica Light HD
   - E mais...
3. **Fixacao Frentes** — estilo de fixacao da frente
4. **Fixacao Gaveta** — fixacao da gaveta na caixa
5. **Frente de Gaveta** — estilo da frente/face
6. **Fundos Gaveta** — tipo de fundo da gaveta
7. **Sistema Corredicoa** — troca o SISTEMA inteiro (4 opcoes):
   - Conjunto Gaveta Metalica Alta Hettich (tipo Legrabox)
   - Conjunto Gaveta Metalica Baixa Hettich
   - Corredicoa Invisivel (oculta/undermount — tipo TANDEM/Blum)
   - Corredicoa Telescopica (volta ao padrao)

### 12.5 Codigos de Pecas de Gaveta no JSON

- `CM_LEG` — Lateral Esquerda Gaveta (upmdraw: FT2x1)
- `CM_LDG` — Lateral Direita Gaveta (upmdraw: FT2x1)
- `CM_FUN_GAV_VER` — Fundo Vertical Gaveta (upmdepth: 6.5mm)
- `CM_CHGAV` — Chapa MDF Gaveta
- `CM_CFG` — Contra Frente Gaveta
- `CM_FRE_GAV_LIS` — Frente Gaveta Lisa
- `CM_TRG` — Traseira Gaveta

---

## 13. SISTEMA DE TROCAS — Arquitetura Contextual

### 13.1 Principio Fundamental

O sistema de **Trocas** e COMPLETAMENTE CONTEXTUAL:
- Quando um **modulo** esta selecionado → mostra trocas gerais (fixacao, estilo, fundo)
- Quando uma **gaveta** esta selecionada → mostra 7 grupos especificos de gaveta
- Quando uma **porta** esta selecionada → mostra opcoes de porta

### 13.2 Trocas para Modulo Geral (sem agregado selecionado)

- Fixacao com Reguas
- Fixacao Lateral
- Fixacao Regua Deitada
- Fundos (trocar tipo de fundo)
- Regua Dianteira

### 13.3 Trocas para Gaveta (gaveta selecionada)

Ver secao 12.4 acima.

### 13.4 Trocas para Porta (porta selecionada)

Provavelmente inclui:
- Tipo de dobradica
- Tipo de puxador
- Estilo da porta
- Tipo de vidro (se porta com vidro)

---

## 14. ARQUITETURA DE EXPORTACAO

### 14.1 Modelo Geral

```
Plugin SketchUp (UpMobb)
    |
    | exporta JSON rico
    v
Plataforma Online UpMobb
    |
    |-- Plano de corte (otimizacao)
    |-- Arquivos CNC (G-code)
    |-- Etiquetas de peca
    |-- Orcamento
    |-- Listagem de compras
    v
Producao na fabrica
```

**IMPLICACAO PARA ORNATO**: O plugin exporta JSON → ERP processa tudo. Esta e a arquitetura correta!

### 14.2 Configuracoes de Exportacao (antes de gerar JSON)

**Detalhes do projeto** (dialog pre-exportacao):
- Meu codigo
- Projetista
- Cliente
- Descricao do projeto
- Adicionais (text area)

**Configuracoes de Usinagem** (engrenagem em Arquivos de Usinagem):

*Lados de exportacao:*
- Exportar lado A (toggle ON/OFF)
- Exportar Lado B (toggle ON/OFF)
- Exportar Topos (toggle ON/OFF)
- Furos de topo no lado B (toggle ON/OFF)
- Adicionar prefixo em codigo de usinagem (toggle ON/OFF)
- Tamanho fixo do codigo (toggle ON/OFF)

*Tipos de trabalhos:*
- Exportar Furos (toggle ON/OFF)
- Exportar Rebaixos/rasgo de serra (toggle ON/OFF)
- Exportar Usinagens (toggle ON/OFF)

### 14.3 Secoes de Exportacao (Accordion)

1. **Exportar para outros sistemas**: UpMobb, SIS Marcenaria
2. **Exportar listagens**: Itens a comprar, Vidros e espelhos, Perfis e lineares, Componentes a conferir
3. **Informacoes de producao**: Listagem de pecas (⚙️), Imagem de peca, Etiqueta completa, Etiqueta peca composta, Etiqueta porta de aluminio, Arquivos de usinagem (⚙️)
4. **Outros**: funcionalidades adicionais

---

## 15. ESTRUTURA DO JSON EXPORTADO — Analise Completa

**Arquivo analisado**: Sem nome.json (117.542 caracteres, 24 pecas)

### 15.1 Tres Secoes de Topo

```json
{
  "model_entities": { ... },   // dados das pecas (28 codigos unicos)
  "details_project": { ... },  // metadados do projeto
  "machining": { ... }         // dados CNC por peca (21 entradas)
}
```

**details_project campos:**
- `client` — nome do cliente
- `project` — nome do projeto
- `my_code` — codigo interno
- `seller` — vendedor/projetista
- `type_material_panel` — tipo de material (MDF)

### 15.2 Codigos de Pecas (upmcode) — 28 tipos unicos

**Modulos:**
- `CM_BAL` — Balcao (modulo pai)

**Pecas de caixaria:**
- `CM_LAT_DIR` — Lateral Direita
- `CM_LAT_ESQ` — Lateral Esquerda
- `CM_REG` — Regua Deitada
- `CM_BAS` — Base (tampo inferior)
- `CM_FUN_VER` — Fundo Vertical
- `CM_FUN_HOR` — Fundo Horizontal
- `CM_DIV` — Divisoria
- `CM_PRA` — Prateleira MDF
- `CM_TRG` — Traseira

**Pecas de gaveta:**
- `CM_LEG` — Lateral Esquerda Gaveta
- `CM_LDG` — Lateral Direita Gaveta
- `CM_FUN_GAV_VER` — Fundo Vertical Gaveta (6.5mm)
- `CM_CHGAV` — Chapa MDF Gaveta
- `CM_CFG` — Contra Frente Gaveta
- `CM_FRE_GAV_LIS` — Frente Gaveta Lisa

**Pecas de porta:**
- `CM_POR_LIS` — Porta Lisa
- `CM_CHPOR_VER_DIR` — Chapa Porta Vertical Direita
- `CM_CHPOR_VER_ESQ` — Chapa Porta Vertical Esquerda

**Usinagens:**
- `CM_USI_RAS` — Usinagem Rasgo de Serra / Rebaixo para Fundo

**Ferragens/Hardware:**
- `CM_KIT_MIN15TW_16_PLAST_BRANCO` — Minifix plastico branco
- `CM_KIT_MIN15TW_19` — Minifix 19
- `CM_KIT_CAV_8X28` — Cavilha 8x28
- `CM_KIT_PAR_4X25` — Parafuso 4x25
- `CM_KIT_COR_HAFELE_H45_S_SC_500` — Corredicoa Hafele H45 500mm
- `CM_KIT_HAFELE_DOB_ALT_110_SC_CF4_NIQ` — Dobradica Hafele 110° Alt
- `CM_KIT_HAFELE_DOB_RET_110_SC_CF4_NIQ` — Dobradica Hafele 110° Ret (reta)

**Fita de borda:**
- `CMBOR19X045BRANCO_TX` — Fita branco tx 19x0.45mm

### 15.3 Campos de uma Peca (model_entities > piece)

```json
{
  "upmprocesscodea": "325739A",    // codigo de producao lado A
  "upmprocesscodeb": "325739B",    // codigo de producao lado B
  "upmpersistentid": 325739,       // ID persistente do SketchUp
  "upmnamefile": "Sem nome",       // nome do arquivo do projeto
  "upmpiece": true,                // marcador: e uma peca
  "upmmasterdescription": "Balcao", // modulo pai
  "upmmasterid": 1,                // ID do modulo pai
  "upmcode": "CM_LAT_DIR",        // tipo da peca
  "upmdescription": "Lateral Direita",
  "upmdepth": "550",               // profundidade mm
  "upmheight": "694.5",            // altura mm
  "upmwidth": "15.5",              // largura mm (espessura)
  "upmlength": "1169",             // comprimento mm (para reguas)
  "upmdraw": "FTE1x2",             // codigo de desenho/orientacao
  "upmedgeside1": "CMBOR19X045BRANCO_TX", // fita lado 1
  "upmedgeside2": "CMBOR19X045BRANCO_TX", // fita lado 2
  "upmedgeside3": "CMBOR19X045BRANCO_TX", // fita lado 3
  "upmedgeside4": "",              // sem fita lado 4
  "upmedgesides": "2C1L",          // resumo: 2 comprimentos 1 largura
  "upmedgesidetype": "2C+1L",      // tipo: 2C+1L
  "upmfinish": "BRANCO_TX",        // acabamento
  "upmtextaggregates": "",         // texto de agregados
  "entities": { ... }              // sub-entidades (painel + fitas + ferragens)
}
```

### 15.4 Sub-entidades de uma Peca (entities)

**Painel MDF** (upmfeedstockpanel: true):
```json
{
  "upmfeedstockpanel": true,
  "upmallowtransferjob": 1,
  "upmcutlist": 1,
  "upmcutlength": "694.5",         // comprimento de corte mm
  "upmcutwidth": "550",            // largura de corte mm
  "upmcutthickness": "15.5",       // espessura de corte mm
  "upmcutliquidlength": "694.5",   // comprimento liquido (pos-usinagem)
  "upmcutliquidwidth": "550",      // largura liquida
  "upmdescription": "Chapa de MDF",
  "upmextralength": "0",           // ajuste de comprimento (-1 para encaixe em rasgo)
  "upmextrawidth": "0",            // ajuste de largura
  "upmfinish": "BRANCO_TX",
  "upmjobaxis": "xyz",
  "upmmaterialcode": "MDF_15.5_BRANCO_TX",  // codigo do material
  "upmmaterialtype": "MDF",
  "upmquantity": "0.381975",       // area em m2
  "entities": {}
}
```

**Fita de Borda** (upmedge: 1):
```json
{
  "upmcode": "CMBOR19X045BRANCO_TX",
  "upmdescription": "Fita de borda branco tx 19x045",
  "upmedge": 1,
  "upmdisable": "0",
  "upmfinish": "BRANCO_TX",
  "upmquantity": "0.7545",         // metros lineares
  "upmtextaggregates": "Comprimento_Frontal", // posicao na peca
  "upmwidth": "754.5",             // comprimento real da fita mm
  "entities": {}
}
```

**Posicoes de Fita de Borda** (upmtextaggregates):
- `Comprimento_Frontal` — lado frontal do comprimento
- `Comprimento_Traseiro` — lado traseiro do comprimento
- `Largura_esquerda` — lado esquerdo da largura
- `Largura_direita` — lado direito da largura

**Hardware** (minifix, cavilha, etc.):
```json
{
  "upmcode": "CM_KIT_MIN15TW_16_PLAST_BRANCO",
  "upmdescription": "Minifix",
  "upmfinish": "PLAST_BRANCO",
  "upmtestbounds": "1",
  "entities": {}
}
```

**Usinagem** (CM_USI_RAS):
```json
{
  "upmcode": "CM_USI_RAS",
  "upmcornerradius": "0",
  "upmdepth": "8",                 // profundidade do rasgo mm
  "upmdescription": "Rasgo de serra",  // ou "Rebaixo para fundo"
  "upmdisable": "0",
  "upmjobcategory": "Transfer_vertical_saw_cut",
  "upmlength": "709.5",            // comprimento do rasgo mm
  "upmquantity": "0.7095",
  "upmtestbounds": "2",
  "upmtool": "r_f",                // ferramenta: rasgo fundo
  "upmwidth": "7",                 // largura do rasgo mm
  "entities": {}
}
```

### 15.5 Codigos upmdraw — 14 tipos

Codificam a orientacao/posicao da peca no modulo:
```
FTE1x2   = Frontal Topo Esquerda (lateral direita)
FTD1x2   = Frontal Topo Direita (lateral esquerda)
FT1x3    = Frontal Topo (regua)
FT2x1    = Frontal Topo (lateral gaveta)
E2x1     = Esquerda (fundo vertical)
F2x1     = Frontal (prateleira)
FD1x2    = Frontal Direita
FE1x2    = Frontal Esquerda
F1x2     = Frontal
F1x3     = Frontal largo
FED1x3   = Frontal Esquerda Direita
FTED1x3  = Frontal Topo Esquerda Direita (base/tampo - 4 lados)
FTED2x1  = Frontal Topo Esquerda Direita (variante)
2x1      = generico
```

### 15.6 Codigos upmedgesides — 8 tipos

```
(vazio)  = sem fita de borda
1C       = 1 lado comprimento
1C1L     = 1 comprimento + 1 largura
1C2L     = 1 comprimento + 2 larguras
1L       = 1 lado largura
2C       = 2 lados comprimento
2C1L     = 2 comprimentos + 1 largura
2C2L     = 2 comprimentos + 2 larguras (= 4Lados = todos os lados)
```

### 15.7 Codigos de Material

```
MDF_15.5_BRANCO_TX   = MDF 15.5mm acabamento Branco Texturizado
MDF_6.5_BRANCO_TX    = MDF 6.5mm acabamento Branco Texturizado (fundos/gavetas)
```

**Formato do codigo**: `{TIPO}_{ESPESSURA}_{ACABAMENTO}`

### 15.8 Secao "machining" — Dados CNC por Peca

Esta secao contem os dados completos para geracao de G-code, indexada por `upmpersistentid`:

```json
{
  "machining": {
    "<persistentid>": {
      "code": "325739A",
      "name_peace": "Lateral Direita",
      "length": 694.5,
      "width": 550,
      "thickness": 15.5,
      "borders": [                   // fitas das 4 bordas
        "CMBOR19X045BRANCO_TX",
        "CMBOR19X045BRANCO_TX",
        "CMBOR19X045BRANCO_TX",
        ""
      ],
      "workers": {                   // operacoes CNC
        "<id>": {
          "category": "transfer_hole",              // furo
          "tool": "f_8mm_cavilha",                  // ferramenta
          "face": "top",                            // face da peca
          "x": ..., "y": ..., "depth": ...
        },
        "<id>": {
          "category": "Transfer_vertical_saw_cut",  // rasgo
          "tool": "r_f",
          "face": "left",
          ...
        }
      }
    }
  }
}
```

### 15.9 Ferramentas CNC (machining > workers > tool) — 9 tipos

```
f_15mm_tambor_min     = Furo 15mm para tambor do minifix
f_35mm_dob            = Furo 35mm para cup da dobradica
f_3mm                 = Furo 3mm generico
f_5mm_twister243      = Furo 5mm Twister 243
f_8mm_cavilha         = Furo 8mm para cavilha
f_8mm_eixo_tambor_min = Furo 8mm para eixo do minifix
p_3mm                 = Pocket 3mm
p_8mm_cavilha         = Pocket 8mm para cavilha
r_f                   = Rasgo de fundo (saw cut)
```

### 15.10 Categorias de Operacao CNC (machining > workers > category)

```
transfer_hole             = Furacao (todos os tipos de furo)
Transfer_vertical_saw_cut = Rasgo de serra / rebaixo
```

### 15.11 Estatisticas do Arquivo de Exemplo

- **Total de pecas**: 24 (upmpiece: true)
- **Tamanho do arquivo**: ~117.542 caracteres
- **Modulos no projeto**: 2 (model_entities tem 2 entradas)
- **Entradas CNC**: 21 (machining dict)
- **Materiais usados**: 2 (MDF 15.5mm e MDF 6.5mm)
- **Fita de borda**: 1 tipo (CMBOR19X045BRANCO_TX — branca 19x0.45mm)

---

## 16. IMPLICACOES PARA O PLUGIN ORNATO

### 16.1 JSON de Saida do Ornato

O plugin Ornato deve gerar um JSON com a mesma estrutura para compatibilidade com o ERP:

```json
{
  "model_entities": {
    "<modulo_idx>": {
      "upmcode": "CM_BAL",          // codigo do tipo de modulo
      "upmdescription": "Balcao",   // descricao legivel
      "upmwidth": "900",             // largura configurada
      "upmheight": "710",            // altura configurada
      "upmdepth": "550",             // profundidade configurada
      "upmfinish": "BRANCO_TX",      // acabamento selecionado
      "upmmasterid": 1,              // ID sequencial
      "entities": {
        "<peca_idx>": {             // cada peca do modulo
          "upmpiece": true,
          "upmcode": "CM_LAT_DIR",
          "upmpersistentid": <id_sketchup>,
          "upmprocesscodea": "<id>A",
          "upmprocesscodeb": "<id>B",
          "upmcutlength": <dim>,
          "upmcutwidth": <dim>,
          "upmcutthickness": <esp>,
          "upmedgeside1/2/3/4": <codigo_fita>,
          "upmedgesides": "2C1L",
          "upmmaterialcode": "MDF_15.5_BRANCO_TX",
          "entities": {
            "0": { "upmfeedstockpanel": true, ... },  // painel de corte
            "1..n": { "upmedge": 1, ... },             // fitas de borda
            "n+1..": { "upmcode": "CM_KIT_...", ... }  // ferragens
          }
        }
      }
    }
  },
  "details_project": {
    "client": ..., "project": ..., "my_code": ...,
    "seller": ..., "type_material_panel": "MDF"
  },
  "machining": {
    "<persistentid>": {
      "code": ..., "name_peace": ...,
      "length": ..., "width": ..., "thickness": ...,
      "borders": [...],
      "workers": { ... }
    }
  }
}
```

### 16.2 Campos Criticos para motor_usinagem.rb

- Gerar `upmprocesscodea/b` unicos por peca
- Calcular `upmextralength/upmextrawidth` (-1mm para pecas que encaixam em rasgo)
- Gerar entrada `CM_USI_RAS` como sub-entidade de laterais com fundo em rasgo
- Calcular `upmquantity` corretamente: area m2 para paineis, metros lineares para fitas

### 16.3 Campos Criticos para motor_fita_borda.rb

- Mapear `upmedgeside1/2/3/4` com codigo da fita correta
- Calcular `upmedgesides` / `upmedgesidetype` (1C, 2C1L, 4Lados, etc.)
- Calcular `upmtextaggregates` para posicao da fita (Comprimento_Frontal, etc.)
- Calcular `upmquantity` em metros lineares (+10mm de folga tipico)

### 16.4 Notas de Victor sobre o Sistema

- "O arquivo vai com as usinagens, tamanhos, laminacoes e etc. O G-code e feito online"
- "Ele so exporta um JSON, o resto e importado online numa plataforma deles e la e feita toda essa configuracao"
- Plugin e apenas o front-end de modelagem — toda inteligencia de producao fica na nuvem

---

## 17. Sistema de Alinhamento / Encaixe entre Módulos

### 17.1 Snap Automático

- Ao aproximar um módulo de outro, o SketchUp faz **auto-snap** automaticamente
- O usuário só precisa **confirmar** o posicionamento (não é drag manual livre)
- Aproveita o sistema nativo de inferências do SketchUp (pontos, arestas, faces)
- Não há lógica proprietária de snap — é o próprio motor do SketchUp

### 17.2 Laterais Separadas por Módulo

- Cada módulo possui suas **próprias laterais independentes**
- Módulos adjacentes **NÃO compartilham** peças entre si
- Quando dois módulos ficam lado a lado: ficam duas laterais coladas (uma de cada módulo)
- Isso simplifica a lógica de geração de peças — cada módulo é autossuficiente

### 17.3 Lateral Passante vs Base Passante

**Lateral Passante** (padrão mais comum):
- A lateral se estende pela **altura total** do módulo
- A base fica **entre as laterais** (encaixada internamente)
- Largura da base = largura total − (2 × espessura da lateral)
- Exemplo: módulo 600mm, lateral 15mm → base = 600 − 30 = 570mm

**Base Passante** (variação):
- A base se estende pela **largura total** do módulo
- A lateral fica **entre a base e o tampo**
- Altura da lateral = altura total − espessura da base − espessura do tampo

### 17.4 Implicações para motor_caixa.rb

```ruby
# Lógica de calculo de dimensoes conforme tipo passante
if lateral_passante
  base_largura = modulo_largura - (2 * espessura)
  lateral_altura = modulo_altura
else # base_passante
  base_largura = modulo_largura
  lateral_altura = modulo_altura - espessura - espessura_tampo
end
```

---

## 18. Sistema de Prateleiras

### 18.1 Inserção

- Acesso: **Agregados → Internos → Prateleira** (ou similar)
- Insere-se **uma prateleira** e depois configura a quantidade desejada
- Sem limite fixo de quantidade documentado

### 18.2 Modos de Posicionamento

#### Paramétrico (automático)
- O plugin **divide o vão igualmente** entre as prateleiras
- Exemplo: vão de 600mm, 2 prateleiras → cada uma a 200mm do vão
- Ideal para projetos rápidos e espaçamento uniforme

#### Não-Paramétrico (manual)
- Abre campos individuais para cada prateleira
- O usuário preenche a **altura de cada uma** manualmente
- Permite espaçamentos irregulares conforme necessidade

### 18.3 Fixação vs Regulável

**Prateleira Fixa**:
- Posicionada em uma altura definitiva
- Encaixada via rasgo ou fixação direta

**Prateleira Regulável**:
- Utiliza **furos de regulagem** (pinos) nas laterais
- Quando selecionada, aparece opção para definir **quantas regulagens** (quantidade de furos de regulagem)
- Permite reposicionar a prateleira após montada

### 18.4 Posição da Prateleira

**Profundidade (eixo Z — frente/fundo):**
- Por padrão, a prateleira fica **encostada no fundo** (profundidade total do módulo)
- Existe opção de **recuo de frente**: desloca a prateleira para frente, liberando espaço
  para portas embutidas (ex: porta de correr interna, porta rebatível interna)
- Parâmetro: `recuo_frente` em mm

**Altura (eixo Y — posição vertical):**
- A altura é sempre definida em relação à **base do móvel** (distância do piso do módulo)
- Após inserir, aparecem os campos de configuração preenchidos **conforme a quantidade de prateleiras**
  informada (1 campo de altura por prateleira)

**Fluxo completo de inserção:**
1. Agregados → Internos → Prateleira
2. Insere uma prateleira no módulo
3. Define a quantidade (1..N)
4. Escolhe modo: **Paramétrico** (divide vão igualmente) ou **Manual** (campo por campo)
5. No modo manual: preenche a altura de cada prateleira (distância da base em mm)
6. Configura tipo: **Fixa** ou **Regulável** (com quantidade de furos de regulagem)
7. Configura recuo de frente se necessário (para portas embutidas)

---

## 19. Etiquetas, Listagem de Peças, Orçamento e Expedição

### 19.1 Escopo — Plataforma Online (fora do plugin)

Estas funcionalidades são **100% online** (plataforma UpMobb web), fora do plugin SketchUp:
- Etiquetas de peças (código de barras, dados de corte)
- Listagem / BOM (Bill of Materials)
- Orçamento / precificação
- Plano de corte (otimização)
- Expedição / romaneio

### 19.2 Fluxo

```
Plugin SketchUp → Exporta JSON → Upload plataforma online →
→ Orçamento / Plano de Corte / Etiquetas / G-code / Expedição
```

### 19.3 Nota para Plugin Ornato

- Foco atual: **replicar a parte de modelagem** do plugin SketchUp
- A integração com ERP Ornato (orçamento, plano de corte, etiquetas, expedição)
  será documentada em **sessão separada**, após a modelagem estar completa

> *(Detalhamento da plataforma online a ser documentado em sessão futura com Victor)*

---

## 20. Tampos (Tamponamento)

### 20.1 Funcionamento

- Seleciona-se um ou mais módulos na cena
- O plugin **envolve automaticamente** os módulos com o tampo
- Não há configuração complexa de geometria — o tampo se adapta ao conjunto selecionado
- Aplicável a balcões, mesas, bancadas

### 20.2 Nota para Plugin Ornato

- Implementar como: selecionar módulos → gerar tampo paramétrico que envolve o conjunto
- Calcular: largura total do conjunto + balanços laterais configuráveis
- Peça gerada: CM_TAM (tampo)

---

## 21. Pés e Rodapés

### 21.1 Funcionamento

- São **caixas pré-prontas** (módulos específicos para base)
- Inseridos como qualquer outro módulo do catálogo
- Documentação completa a ser feita em sessão futura com Victor

---

## 22. Peças Avulsas

### 22.1 Conceito

- Peças que podem ser inseridas **independentemente** na cena
- **Não precisam estar conectadas** a um módulo (diferente dos Agregados)
- Exemplos de tipos: chapas, réguas, frentes de gaveta, painéis avulsos, etc.

### 22.2 Diferença vs Agregados

| | Peças Avulsas | Agregados |
|--|--|--|
| Conexão | Independente (livre na cena) | Vinculado a um módulo pai |
| Inserção | Direta na cena | Requer módulo selecionado |
| Uso típico | Chapas, frentes, réguas soltas | Gavetas, prateleiras, portas |

### 22.3 Nota para Plugin Ornato

- Implementar via `motor_pecas_avulsas.rb` (já existe no projeto)
- Peças sem pai (parent_id = nil) no JSON exportado

---

## 23. Templates de Ambiente — OPORTUNIDADE DE DIFERENCIAÇÃO

### 23.1 Status no UpMobb

> **Templates de ambiente NÃO existem no UpMobb.**
> O plugin não possui modelos prontos de cozinha, quarto, banheiro, etc.

### 23.2 Oportunidade para Plugin Ornato

Este é um **ponto de diferenciação competitiva** do Plugin Ornato:
- Criar **ambientes completos prontos**: cozinha, dormitório, banheiro, lavanderia, escritório
- O usuário seleciona um template → toda a cozinha é inserida na cena com um clique
- Módulos parametrizados → ajustam-se ao tamanho do ambiente
- Economiza horas de projeto para projetos recorrentes

### 23.3 Implementação Sugerida

```ruby
# motor_templates.rb (já existe no projeto)
# Fluxo:
# 1. Usuário escolhe ambiente (cozinha, dormitório, etc.)
# 2. Escolhe template específico (cozinha em L, cozinha em U, etc.)
# 3. Define dimensões do ambiente (largura, altura, profundidade)
# 4. Plugin insere todos os módulos posicionados automaticamente
# 5. Usuário ajusta individualmente se necessário
```

### 23.4 Templates Sugeridos por Ambiente

- **Cozinha**: Linear, Em L, Em U, Paralela, Com ilha
- **Dormitório**: Closet linear, Closet em L, Guarda-roupa embutido
- **Banheiro**: Gabinete + espelheira, Coluna
- **Lavanderia**: Armário + bancada
- **Escritório**: Estante + mesa

---

*Documento gerado em 28/02/2026 durante investigacao do UpMobb via Chrome Remote Desktop*
*Atualizado com visita guiada do Victor em 28/02/2026*
*Atualizado com pesquisa de tipos de dobradica (reta/curva/supercurva) em 28/02/2026*
*Atualizado com analise completa do JSON exportado e sistema de gavetas em 28/02/2026*
*Atualizado com sistema de alinhamento, lateral passante e prateleiras em 28/02/2026*
*Atualizado com posicao de prateleiras (recuo frente, altura pela base) e escopo online em 28/02/2026*
*Atualizado com mapeamento completo dos 11 grupos de Trocas gerais em 28/02/2026*
*Atualizado com tampos, pes/rodapes, pecas avulsas e oportunidade de templates em 28/02/2026*
*Atualizado com exploracao completa da plataforma web UpMobb (app.upmobb.net) em 28/02/2026*
*Para uso na replicacao das funcionalidades no Plugin Ornato*

---

## 24. PLATAFORMA WEB UPMOBB — Exploracao Completa (app.upmobb.net)

> Exploracao realizada em 28/02/2026 via Chrome em app.upmobb.net
> Lote de teste: "teste otimizador" (batch=21460, 45 pecas, 2 modulos)

### 24.1 Visao Geral da Plataforma

A plataforma web UpMobb (app.upmobb.net) e onde acontece TODO o processamento de producao:
- **Otimizacao de plano de corte** (nesting)
- **Geracao de G-code CNC**
- **Impressao de etiquetas**
- **Gerenciamento de materiais e sobras**
- **Configuracao do otimizador**

O fluxo e: Plugin SketchUp → Exporta JSON → Upload na plataforma → Processamento completo

### 24.2 Toolbar da Plataforma (12 icones)

```
1. Controle de sobras          — gerenciar retalhos de chapa
2. Marcar para Editar          — selecionar pecas para edicao
3. Plano de corte              — visualizar otimizacao de chapas
4. Lista de pecas              — tabela completa de todas as pecas
5. Exportar Plano de corte     — gerar arquivo de plano de corte/CNC
6. Imprimir Etiquetas          — gerar etiquetas para producao
7. Importar lista de pecas     — importar JSON do plugin
8. Exportar lista              — exportar lista de pecas
9. Limpar entrada              — limpar dados
10. Estoque de materiais       — gerenciar chapas disponíveis
11. Lotes de producao          — gerenciar batches
12. Configuracoes do otimizador — parametros de nesting/CNC
```

### 24.3 Tabela de Pecas — 22 Colunas

A listagem de pecas importada do JSON mostra 22 colunas:

```
#                    — checkbox de selecao
Item                 — numero sequencial (1-45)
quantidade           — qtd de pecas identicas
material             — ex: "MDF Branco tx 18mm"
comprimento          — dimensao em mm
largura              — dimensao em mm
borda direita        — codigo da fita (ex: CMBOR22x045BRANCO_TX)
borda esquerda       — codigo da fita
borda frontal        — codigo da fita
borda traseira       — codigo da fita
Acabamento           — codigo resumo (1C, 2C, 2C+1L, 1C+2L, 4Lados)
Cliente              — nome do cliente
Descricao peca       — ex: "Lateral Direita", "Base MDF"
Descricao projeto    — nome do projeto
Id Master            — ID do modulo pai
Id Peca              — ID unico da peca
Meu codigo           — codigo interno do projeto
Observacao            — campo livre
Produto final        — ex: "Armario Alto", "Balcao teste"
Qtde pecas modulo    — quantidade total de pecas no modulo
UsiA                 — codigo de usinagem lado A (ex: "325739A")
UsiB                 — codigo de usinagem lado B (ex: "325739B")
```

### 24.4 Dados Observados no Lote de Teste

```
Total de pecas:        45
Descricoes unicas:     17 tipos de peca
Materiais:             3 (MDF Branco tx 18mm, 15mm, 6mm)
Fitas de borda:        3 codigos (CMBOR22x045, CMBOR19X045, CMBOR22X045)
Acabamentos:           6 tipos (1C, 1C+2L, 2C, 2C+1L, 1C+1L, 4Lados)
Produtos finais:       2 (Armario Alto, Balcao teste)
```

### 24.5 Sistema de Etiquetas

Ao clicar "Imprimir Etiquetas", abre preview com formato padrao:

```
┌──────────────────────────────────────────────────┐
│ Usinagem A: 325739A    Usinagem B: 325739B       │
│ Material: MDF Branco tx 6mm                      │
│ Cliente: Victor        Desc. projeto: teste       │
│ Modulo: Balcao teste   Peca: Fundo MDF           │
│ ID Mod.: 2             Controle: 42               │
│ Fita de borda: CMBOR19X045BRANCO_TX              │
│                                                    │
│ ┌─────────────────┐  ┌──────┐                     │
│ │   DIAGRAMA       │  │ |||  │  ← Barcode         │
│ │   da peca com    │  │ |||  │                     │
│ │   indicadores    │  └──────┘                     │
│ │   de fita borda  │                               │
│ └─────────────────┘  Expedicao: 42                 │
│                                                    │
│ Fita: 19X045 - BRANCO TX              │ 42 │      │
└──────────────────────────────────────────────────┘
```

**Campos da etiqueta:**
- Usinagem A/B (codigos de producao)
- Material (nome completo)
- Cliente + Descricao do projeto
- Modulo + Peca (descricao)
- ID Modulo + Controle (numero sequencial)
- Fita de borda (codigo)
- Diagrama visual da peca com indicadores de fita em cada borda
- Barcode + Expedicao
- Numero grande vertical na lateral direita (ID)

**Nota:** UpMobb possui plataforma propria de edicao de etiquetas — abre uma folha
onde o usuario pode personalizar layout com base em variaveis pre-determinadas.

### 24.6 Configuracoes do Otimizador

Pagina: `production_optimizer_setting.html`

#### Padroes de Importacao
- **Padrao**: "UpMobb 3D" — Importador para arquivos UpMobb
- Permite selecionar qual parser usar para o JSON importado

#### Motor de Calculo
- **Motor**: R-Hex
- **Calcular para**: Nesting (otimizacao de chapas)
- **Rotacao de peca sem veio**: ON (pecas sem direcao de veio podem ser rotacionadas)

#### Configuracao de Sobras
- **Considerar sobra**: ON — reaproveitar retalhos de cortes anteriores
- **Adicionar automatico**: ON — registrar novas sobras automaticamente
- **Dimensao minima de sobra**: 600 × 300 mm

#### Parametros de Nesting
- **Tipo**: Furos | Rebaixos | Usinagens
- **Aplicar**: Lado A
- **Sentido**: Horario
- **Formato saida**: .nc (G-code)
- **Z seguro**: 30 mm (altura de recuo entre operacoes)
- **Velocidade vazio**: 20.000 mm/min (rapido entre posicoes)
- **Espaco entre pecas**: 7 mm
- **Profundidade extra**: 0.20 mm (para garantir corte completo)

#### Pecas Pequenas
- **Estrategia**: Cortar primeiro
- **Velocidade**: 4.000 mm/min
- **Passos**: 1 passo
- **Passo reservado**: 0.20 mm

#### Validacoes
- **Dimensao minima de peca**: 200 × 200 mm

#### Deslocamentos CNC
- Deslocamentos X/Y/Z configuráveis para lado A e lado B/reverso
- Permite ajustar offset da maquina CNC

#### Furos e Usinagens (toggles)
- **Furos**: ON/OFF
- **Rebaixos/corte de serra**: ON/OFF
- **Usinagens ponto a ponto**: ON/OFF

#### G-code — Instrucoes Iniciais e Finais

```gcode
# Instrucoes iniciais (header):
%
M71 M10 G90 G00 G54 G17

# Instrucoes finais (footer):
G0 Z200.000
G40 M5 M74 M72 M11
G0 X500.000 Y2000.000
M141 M30
%
```

#### Ferramentas Nesting (Magazine)
```
T01 — Broca 15mm (para minifix/cavilha)
T02 — Broca 35mm (para cup de dobradica)
T03 — Broca 3mm  (para furos piloto)
```

### 24.7 Armazem de Materiais (Chapas)

Pagina: `production_stock_panel.html`

#### Materiais Cadastrados (3 no teste)

| Material | Chapa (mm) | Refilo | Veio |
|---|---|---|---|
| MDF Branco tx 6mm | 2750 × 1850 | 10mm | Sem veio |
| MDF Branco tx 15mm | 2750 × 1850 | 10mm | Sem veio |
| MDF Branco tx 18mm | 2750 × 1850 | 10mm | Sem veio |

**CONFIRMACAO CRITICA**: Ao editar o material "MDF 18mm", a espessura real
configurada e **18,50 mm** (nao 18mm nominal). Isso confirma que o UpMobb
tambem usa espessuras reais de MDF, identico ao Ornato:

```
Nominal → Real (UpMobb/Ornato)
6mm     → 6.5mm
15mm    → 15.5mm
18mm    → 18.5mm
25mm    → 25.5mm
```

#### Parametros de cada chapa:
- Espessura (mm) — espessura REAL
- Comprimento da chapa (mm) — ex: 2750
- Largura da chapa (mm) — ex: 1850
- Refilo (mm) — margem de corte nas bordas (ex: 10mm)
- Veio — direcao do veio (sem veio / horizontal / vertical)

#### Lista de Sobras
- Pagina separada para gerenciar retalhos de chapas cortadas
- No teste: vazia (nenhuma sobra registrada)
- Funciona em conjunto com "Considerar sobra: ON" do otimizador

### 24.8 Plano de Corte (Exportacao)

Ao tentar exportar plano de corte, o sistema verificou configuracoes e retornou:
> "O Furo f_8mm_cavilha parece nao esta configurado"

Isso indica que:
1. O web platform valida as ferramentas CNC antes de gerar o plano
2. Cada furo/usinagem precisa de uma ferramenta cadastrada no magazine
3. No teste, apenas T01 (15mm), T02 (35mm) e T03 (3mm) estavam configurados
4. Faltava cadastrar a broca de 8mm para cavilha

### 24.9 Formato de Codigos de Fita de Borda

```
CMBOR{LARGURA}x{ESPESSURA}{ACABAMENTO}

Exemplos:
CMBOR22x045BRANCO_TX   — 22mm largura, 0.45mm espessura, Branco Texturizado
CMBOR19X045BRANCO_TX   — 19mm largura, 0.45mm espessura, Branco Texturizado

Nota: variacao de maiusculas (x vs X) observada nos dados
```

### 24.10 Formato de Codigos de Acabamento

```
1C      — 1 lado comprimento com fita
1C+1L   — 1 comprimento + 1 largura
1C+2L   — 1 comprimento + 2 larguras
2C      — 2 lados comprimento
2C+1L   — 2 comprimentos + 1 largura
4Lados  — todos os 4 lados (= 2C+2L)
```

### 24.11 Arquitetura Completa Plugin → Web

```
┌─────────────────────────────────┐
│   Plugin SketchUp (Ornato)      │
│                                 │
│ ┌─────────────┐ ┌─────────────┐│
│ │ Modelagem   │ │ motor_export││
│ │ Parametrica │→│ .rb (JSON)  ││
│ └─────────────┘ └──────┬──────┘│
└────────────────────────┼───────┘
                         │ JSON
                         ▼
┌─────────────────────────────────┐
│   Plataforma Web (ERP/Ornato)   │
│                                 │
│ ┌──────────┐ ┌───────────────┐ │
│ │Importador│→│ Otimizador    │ │
│ │ JSON     │ │ (R-Hex/FFD)   │ │
│ └──────────┘ └───────┬───────┘ │
│                      │         │
│ ┌──────┬──────┬──────┼──────┐  │
│ │Plano │Etiqu│G-code│Armazem│  │
│ │Corte │etas │ CNC  │Sobras │  │
│ └──────┴──────┴──────┴──────┘  │
│                                │
│ ┌──────────────────────────┐   │
│ │ Orcamento / Precificacao │   │
│ └──────────────────────────┘   │
└─────────────────────────────────┘
```

---

## 25. RESUMO — O que o Ornato ja tem vs O que falta

### 25.1 Plugin SketchUp (COMPLETO para MVP)

| Funcionalidade | Status | Arquivo |
|---|---|---|
| Caixa parametrica | ✅ OK | motor_caixa.rb |
| Agregados (porta/gaveta/prat/div) | ✅ OK | motor_agregados.rb |
| Portas (9 tipos + dobradicas) | ✅ OK | motor_portas.rb |
| Furacao (minifix/cavilha/system32) | ✅ OK | motor_furacao.rb |
| Fita de borda (4 lados) | ✅ OK | motor_fita_borda.rb |
| Usinagem (canal/rebaixo/rasgo/gola) | ✅ OK | motor_usinagem.rb |
| Pecas avulsas | ✅ OK | motor_pecas_avulsas.rb |
| Plano de corte (FFD) | ✅ OK | motor_plano_corte.rb |
| Templates (20+ modelos) | ✅ OK | motor_templates.rb |
| Precificacao | ✅ OK | motor_precificacao.rb |
| Alinhamento | ✅ OK | motor_alinhamento.rb |
| Inteligencia (auto-ferragem) | ✅ OK | motor_inteligencia.rb |
| Validacao (engenharia) | ✅ OK | motor_validacao.rb |
| Etiquetas (producao) | ✅ OK | motor_etiquetas.rb |
| Ficha tecnica | ✅ OK | motor_ficha_tecnica.rb |
| Cotagem (3D) | ✅ OK | motor_cotagem.rb |
| Export JSON (UpMobb compat) | ✅ OK | motor_export.rb |
| UI Painel lateral | ✅ OK | ui/painel.rb |
| UI Propriedades | ✅ OK | ui/propriedades.rb |
| UI Catalogo templates | ✅ OK | ui/catalogo_templates.rb |
| Toolbar (17 botoes) | ✅ OK | toolbar.rb |
| Menu (Ornato) | ✅ OK | menu.rb |
| Context menu (right-click) | ✅ OK | context_menu.rb |
| Observers | ✅ OK | observers.rb |

**Total: 29 arquivos Ruby, 17 engines, ~10.000+ linhas**

### 25.2 Plataforma Web (A CONSTRUIR)

Baseado na exploracao do UpMobb, a plataforma web Ornato precisa de:

| Funcionalidade | Prioridade | Referencia UpMobb |
|---|---|---|
| Importador JSON | ALTA | Importa JSON do plugin |
| Otimizador plano de corte | ALTA | R-Hex/Nesting engine |
| Geracao G-code CNC (.nc) | ALTA | Com header/footer configuravel |
| Etiquetas (editor visual) | ALTA | Editor de layout de etiquetas |
| Armazem de materiais | MEDIA | Cadastro de chapas + espessuras reais |
| Controle de sobras | MEDIA | Registro e reaproveitamento |
| Lotes de producao | MEDIA | Agrupamento de pecas em batches |
| Configuracoes do otimizador | MEDIA | Nesting params, CNC tools |
| Magazine de ferramentas CNC | MEDIA | T01-Tn com brocas/fresas |
| Validacao pre-corte | BAIXA | Checa tools cadastrados |
| Orcamento/precificacao web | BAIXA | Ja tem local (motor_precificacao) |
