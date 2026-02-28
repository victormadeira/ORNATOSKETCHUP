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

#### Grupos de Trocas:
- Fixacao com Reguas
- Fixacao Lateral
- Fixacao Regua Deitada
- Fundos (trocar tipo de fundo)
- Regua Dianteira

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

*Documento gerado em 28/02/2026 durante investigacao do UpMobb via Chrome Remote Desktop*
*Atualizado com visita guiada do Victor em 28/02/2026*
*Atualizado com pesquisa de tipos de dobradica (reta/curva/supercurva) em 28/02/2026*
*Para uso na replicacao das funcionalidades no Plugin Ornato*
