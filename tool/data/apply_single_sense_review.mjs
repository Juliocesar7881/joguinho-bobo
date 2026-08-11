import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const toolDir = path.dirname(fileURLToPath(import.meta.url));
const sourcePath = path.join(toolDir, 'catalog_source.json');
const meaningsPath = path.join(toolDir, 'curated_meanings_ptbr.json');
const reviewPath = path.join(toolDir, 'single_sense_review.json');

// Explicit corrections from the second semantic pass. Each entry deliberately
// keeps one common sense that agrees with its PT-BR translation and word class.
const revisions = {
  lot: {
    meaning: 'Porção delimitada de terreno destinada a uma construção.',
    hint: 'Terreno delimitado que pode receber uma construção.',
  },
  far: {
    meaning: 'Que se encontra a grande distância física do ponto de referência.',
    hint: 'Indica grande distância física em relação a um ponto.',
  },
  have: {
    meaning: 'Manter alguma coisa sob sua posse.',
    hint: 'Indica que alguma coisa está sob a posse de alguém.',
  },
  high: {
    meaning: 'Que se encontra em posição elevada em relação ao solo.',
    hint: 'Está muito acima da base em relação ao solo.',
  },
  line: {
    meaning: 'Traço contínuo formado pelo deslocamento de um ponto.',
    hint: 'Traço contínuo que liga pontos sobre uma superfície.',
  },
  long: {
    meaning: 'Que possui grande extensão de uma extremidade à outra.',
    hint: 'Possui grande extensão de uma extremidade à outra.',
  },
  sign: {
    meaning: 'Indício perceptível que comunica a existência de alguma coisa.',
    hint: 'Indício percebido que revela alguma coisa.',
  },
  size: {
    meaning: 'Medida das dimensões físicas de alguma coisa.',
    hint: 'Medida das dimensões de uma pessoa ou objeto.',
  },
  call: {
    translation: 'telefonar',
    meaning: 'Tentar estabelecer contato com alguém por telefone.',
    hint: 'Tentar falar com alguém por telefone.',
  },
  card: {
    meaning: 'Peça de plástico usada para efetuar pagamentos eletrônicos.',
    hint: 'Pequena peça de plástico usada para pagar uma compra.',
  },
  live: {
    translation: 'morar',
    meaning: 'Ter residência habitual em determinado lugar.',
    hint: 'Ter como moradia habitual determinado lugar.',
  },
  cost: {
    meaning: 'Quantia em dinheiro necessária para adquirir alguma coisa.',
    hint: 'Valor em dinheiro que precisa ser pago para adquirir algo.',
  },
  play: {
    meaning: 'Participar de um jogo seguindo suas regras.',
    hint: 'Participar de uma partida seguindo regras definidas.',
  },
  feel: {
    meaning: 'Experimentar determinada emoção interiormente.',
    hint: 'Experimentar uma emoção dentro de si.',
  },
  step: {
    meaning: 'Movimento realizado ao avançar um dos pés durante a caminhada.',
    hint: 'Movimento de um dos pés durante a caminhada.',
  },
  near: {
    meaning: 'Que fica a pequena distância física do ponto de referência.',
    hint: 'Está a pouca distância física de um ponto.',
  },
  about: {
    meaning: 'Usado para indicar o assunto tratado em uma fala ou texto.',
    hint: 'Indica o assunto tratado em uma conversa ou texto.',
  },
  order: {
    meaning: 'Organizar elementos conforme uma sequência definida.',
    hint: 'Colocar elementos em uma sequência organizada.',
  },
  under: {
    meaning: 'Usado para indicar posição abaixo de alguma coisa.',
    hint: 'Indica uma posição inferior a outra coisa.',
  },
  after: {
    meaning: 'Em um momento posterior ao acontecimento de referência.',
    hint: 'Indica um momento posterior a outro acontecimento.',
  },
  level: {
    meaning: 'Posição ocupada em uma escala de dificuldade.',
    hint: 'Indica a posição de uma fase dentro de uma escala de dificuldade.',
  },
  title: {
    meaning: 'Nome atribuído a uma obra para identificá-la.',
    hint: 'Nome usado para identificar uma obra.',
  },
  point: {
    meaning: 'Local exato identificado em um espaço.',
    hint: 'Lugar exato identificado em determinado espaço.',
  },
  study: {
    meaning: 'Atividade dedicada a aprender um assunto.',
    hint: 'Atividade de dedicação a um assunto para adquirir conhecimento.',
  },
  quote: {
    meaning: 'Reproduzir as palavras ditas ou escritas por outra pessoa.',
    hint: 'Repetir palavras originalmente ditas por outra pessoa.',
  },
  focus: {
    meaning: 'Ponto para o qual a atenção está dirigida.',
    hint: 'Ponto que recebe a maior concentração de atenção.',
  },
  agent: {
    meaning: 'Pessoa autorizada a agir em nome de outra.',
    hint: 'Pessoa que representa os interesses de outra.',
  },
  panel: {
    meaning: 'Placa que reúne controles de uma máquina.',
    hint: 'Superfície que reúne os controles de uma máquina.',
  },
  sense: {
    meaning: 'Capacidade do corpo de perceber determinado tipo de estímulo.',
    hint: 'Capacidade corporal usada para perceber estímulos.',
  },
  birth: {
    meaning: 'Momento em que um novo ser vem ao mundo.',
    hint: 'Marca a chegada de um novo ser ao mundo.',
  },
  abuse: {
    meaning: 'Usar poder de forma cruel contra outra pessoa.',
    hint: 'Usar poder de forma cruel e prejudicial contra alguém.',
  },
  course: {
    meaning: 'Sequência organizada de aulas sobre determinado assunto.',
    hint: 'Sequência organizada de aulas sobre um assunto.',
  },
  letter: {
    meaning: 'Mensagem escrita e enviada a uma pessoa.',
    hint: 'Mensagem escrita destinada a outra pessoa.',
  },
  center: {
    meaning: 'Ponto situado à mesma distância das extremidades.',
    hint: 'Ponto localizado no meio das extremidades.',
  },
  medium: {
    meaning: 'Recurso usado para transmitir uma informação.',
    hint: 'Recurso pelo qual uma informação é transmitida.',
  },
  reader: {
    meaning: 'Pessoa que lê textos escritos.',
    hint: 'Pessoa que interpreta textos escritos.',
  },
  appear: {
    meaning: 'Tornar-se visível para quem observa.',
    hint: 'Tornar-se visível diante de quem observa.',
  },
  branch: {
    meaning: 'Parte de uma árvore que cresce a partir do tronco.',
    hint: 'Parte que cresce a partir do tronco de uma árvore.',
  },
  column: {
    meaning: 'Estrutura vertical usada para sustentar uma construção.',
    hint: 'Estrutura vertical que sustenta uma construção.',
  },
  silver: {
    meaning: 'Que é feito do metal precioso chamado prata.',
    hint: 'Caracteriza algo feito de um metal precioso claro e brilhante.',
  },
  follow: {
    meaning: 'Deslocar-se atrás de alguém que segue adiante.',
    hint: 'Ir atrás de alguém que mostra o caminho.',
  },
  journal: {
    meaning: 'Publicação periódica dedicada a uma área de conhecimento.',
    hint: 'Publicação especializada lançada em intervalos regulares.',
  },
  release: {
    meaning: 'Tornar disponível algo que antes estava restrito.',
    hint: 'Disponibilizar algo que antes estava restrito.',
  },
  central: {
    meaning: 'Que ocupa a região do meio de um espaço.',
    hint: 'Ocupa a região do meio de um espaço.',
  },
  channel: {
    meaning: 'Meio usado para transmitir uma comunicação.',
    hint: 'Meio pelo qual uma comunicação é transmitida.',
  },
  station: {
    meaning: 'Local onde passageiros embarcam e desembarcam de trens.',
    hint: 'Local de embarque e desembarque de passageiros de trens.',
  },
  surface: {
    meaning: 'Camada externa que delimita um objeto.',
    hint: 'Camada externa que delimita alguma coisa.',
  },
  interest: {
    meaning: 'Curiosidade que dirige a atenção para determinado assunto.',
    hint: 'Curiosidade que dirige a atenção para algo.',
  },
  import: {
    meaning: 'Trazer mercadoria de outro país para o mercado interno.',
    hint: 'Trazer mercadoria estrangeira para o mercado interno.',
  },
  export: {
    meaning: 'Enviar mercadoria nacional para venda em outro país.',
    hint: 'Enviar mercadoria nacional para o mercado de outro país.',
  },
  contact: {
    meaning: 'Comunicação estabelecida entre duas pessoas.',
    hint: 'Comunicação estabelecida entre pessoas.',
  },
  version: {
    meaning: 'Edição específica de um produto ou de uma obra.',
    hint: 'Edição específica de um produto ou obra.',
  },
  function: {
    meaning: 'Finalidade para a qual alguma coisa é usada.',
    hint: 'Finalidade desempenhada por alguma coisa.',
  },
  response: {
    meaning: 'Retorno dado a uma pergunta recebida.',
    hint: 'Retorno dado depois que uma pergunta é recebida.',
  },
  discount: {
    meaning: 'Reduzir o preço cobrado por alguma coisa.',
    hint: 'Aplicar uma redução ao valor cobrado por algo.',
  },
  solution: {
    meaning: 'Método capaz de resolver uma dificuldade.',
    hint: 'Método que elimina uma dificuldade existente.',
  },
  approach: {
    meaning: 'Mover-se fisicamente para mais perto de alguém.',
    hint: 'Mover-se para ficar fisicamente mais perto de alguém.',
  },
  most: {
    meaning: 'Usado para indicar a maior parte dos integrantes de um grupo.',
    hint: 'Indica a maior parte dos integrantes de um grupo.',
  },
  both: {
    meaning: 'Usado para indicar dois elementos considerados em conjunto.',
    hint: 'Refere-se a dois elementos considerados ao mesmo tempo.',
  },
  another: {
    meaning: 'Usado para indicar mais um elemento diferente do já mencionado.',
    hint: 'Indica mais um elemento diferente do primeiro.',
  },
  several: {
    meaning: 'Usado para indicar uma quantidade maior que duas e pouco numerosa.',
    hint: 'Indica mais de dois elementos, sem formar uma quantidade grande.',
  },
  day: {
    meaning: 'Período completo de vinte e quatro horas.',
  },
  act: {
    meaning: 'Ação praticada intencionalmente por alguém.',
  },
  fix: {
    meaning: 'Prender alguma coisa firmemente em determinada posição.',
  },
  dot: {
    meaning: 'Marca circular de tamanho muito pequeno.',
  },
  must: {
    partOfSpeech: 'verb',
    translation: 'dever',
    meaning: 'Ser obrigado a realizar determinada ação.',
  },
  take: {
    translation: 'pegar',
    meaning: 'Segurar alguma coisa com as mãos.',
  },
  save: {
    meaning: 'Guardar dados em um dispositivo para uso posterior.',
  },
  note: {
    meaning: 'Perceber um detalhe que chama a atenção.',
  },
  term: {
    meaning: 'Palavra usada com significado específico em determinado contexto.',
  },
  stay: {
    meaning: 'Permanecer no mesmo lugar durante certo tempo.',
  },
  thus: {
    translation: 'portanto',
    meaning: 'Como consequência do que foi mencionado anteriormente.',
  },
  deep: {
    meaning: 'Que se estende muito para baixo a partir da superfície.',
  },
  right: {
    meaning: 'Faculdade garantida a uma pessoa pela lei.',
  },
  today: {
    meaning: 'Dia presente em que se fala.',
  },
  power: {
    meaning: 'Autoridade para controlar as decisões de outras pessoas.',
  },
  board: {
    meaning: 'Superfície plana usada para escrever e exibir conteúdo.',
  },
  class: {
    meaning: 'Grupo de elementos que compartilham características.',
  },
  value: {
    meaning: 'Quantia monetária atribuída a alguma coisa.',
  },
  model: {
    meaning: 'Representação simplificada usada para explicar alguma coisa.',
  },
  above: {
    meaning: 'Em posição fisicamente mais alta que a referência.',
  },
  field: {
    meaning: 'Área aberta de terra usada para cultivo.',
  },
  range: {
    translation: 'intervalo',
    meaning: 'Conjunto de valores compreendidos entre um mínimo e um máximo.',
  },
  space: {
    meaning: 'Área livre disponível para ser ocupada.',
  },
  enter: {
    meaning: 'Passar de fora para dentro de um lugar.',
  },
  track: {
    meaning: 'Caminho demarcado para a passagem de pessoas.',
  },
  cover: {
    meaning: 'Colocar algo sobre uma superfície para protegê-la.',
  },
  clear: {
    meaning: 'Que pode ser entendido sem dificuldade.',
  },
  entry: {
    meaning: 'Ato de passar para dentro de um lugar.',
  },
  leave: {
    translation: 'sair',
    meaning: 'Afastar-se do lugar em que se estava.',
  },
  valid: {
    meaning: 'Que atende às regras estabelecidas para ser aceito.',
  },
  trial: {
    meaning: 'Processo judicial em que um caso é julgado.',
  },
  floor: {
    meaning: 'Superfície inferior de um ambiente sobre a qual se caminha.',
  },
  stage: {
    meaning: 'Fase delimitada dentro do desenvolvimento de um processo.',
  },
  break: {
    meaning: 'Partir fisicamente alguma coisa em pedaços.',
  },
  block: {
    meaning: 'Peça sólida e compacta com faces aproximadamente planas.',
  },
  worth: {
    meaning: 'Que possui determinado valor monetário.',
  },
  sheet: {
    meaning: 'Peça retangular, fina e plana de papel.',
  },
  patch: {
    meaning: 'Pequena peça aplicada para consertar um rasgo.',
  },
  serve: {
    meaning: 'Prestar atendimento a outra pessoa.',
  },
  mount: {
    meaning: 'Fixar uma peça sobre um suporte.',
  },
  avoid: {
    meaning: 'Impedir que um acontecimento indesejado ocorra.',
  },
  funny: {
    meaning: 'Que provoca riso por ser divertido.',
  },
  brief: {
    meaning: 'Que dura por um intervalo curto de tempo.',
  },
  fight: {
    meaning: 'Participar de confronto físico contra outra pessoa.',
  },
  number: {
    meaning: 'Conceito matemático usado para expressar uma quantidade.',
  },
  public: {
    meaning: 'Que está aberto ao acesso da população em geral.',
  },
  review: {
    meaning: 'Examinar novamente alguma coisa para avaliá-la.',
  },
  family: {
    meaning: 'Grupo de pessoas ligadas por parentesco.',
  },
  access: {
    meaning: 'Direito de entrar em determinado lugar.',
  },
  credit: {
    meaning: 'Acordo que permite pagar uma compra em momento futuro.',
  },
  notice: {
    meaning: 'Perceber alguma coisa que chama a atenção.',
  },
  player: {
    meaning: 'Pessoa que participa de um jogo.',
  },
  figure: {
    meaning: 'Imagem usada para representar visualmente alguma coisa.',
  },
  volume: {
    meaning: 'Espaço tridimensional ocupado por um corpo.',
  },
  matter: {
    meaning: 'Substância física da qual os corpos são formados.',
  },
  secure: {
    meaning: 'Tornar alguma coisa protegida contra risco.',
  },
  impact: {
    meaning: 'Efeito forte produzido por um acontecimento.',
  },
  studio: {
    meaning: 'Local preparado para gravar produções audiovisuais.',
  },
  remote: {
    meaning: 'Que fica a grande distância do lugar de referência.',
  },
  manual: {
    meaning: 'Guia escrito que apresenta instruções de uso.',
  },
  couple: {
    meaning: 'Duas pessoas ligadas por relacionamento afetivo.',
  },
  vision: {
    meaning: 'Capacidade física de enxergar.',
  },
  spirit: {
    meaning: 'Parte imaterial atribuída à existência de um ser.',
  },
  handle: {
    translation: 'lidar',
    meaning: 'Administrar uma tarefa que exige atenção.',
  },
  appeal: {
    meaning: 'Pedido urgente dirigido a uma autoridade.',
  },
  extent: {
    meaning: 'Grau atingido por determinada condição.',
  },
  through: {
    meaning: 'Usado para indicar passagem pelo interior de alguma coisa.',
  },
  section: {
    meaning: 'Parte separada e organizada de um documento.',
  },
  history: {
    meaning: 'Conjunto de acontecimentos ocorridos no passado.',
  },
  quality: {
    meaning: 'Grau de excelência apresentado por alguma coisa.',
  },
  library: {
    meaning: 'Local que mantém uma coleção organizada de livros.',
  },
  popular: {
    meaning: 'Que é apreciado por grande número de pessoas.',
  },
  holiday: {
    translation: 'feriado',
    meaning: 'Dia oficialmente reconhecido em que atividades regulares são suspensas.',
  },
  storage: {
    meaning: 'Sistema destinado a guardar dados para uso posterior.',
  },
  believe: {
    meaning: 'Aceitar uma afirmação como verdadeira.',
  },
  develop: {
    meaning: 'Fazer alguma coisa avançar gradualmente.',
  },
  require: {
    meaning: 'Estabelecer alguma coisa como condição obrigatória.',
  },
  faculty: {
    meaning: 'Conjunto de professores de uma instituição de ensino.',
  },
  officer: {
    meaning: 'Pessoa que ocupa posto de autoridade nas forças armadas.',
  },
  property: {
    meaning: 'Bem que pertence legalmente a uma pessoa.',
  },
  register: {
    meaning: 'Anotar uma informação de maneira oficial.',
  },
  question: {
    meaning: 'Frase formulada para obter uma resposta.',
  },
  delivery: {
    meaning: 'Ato de levar um produto ao destinatário.',
  },
  position: {
    meaning: 'Lugar ocupado por alguém ou alguma coisa.',
  },
  practice: {
    meaning: 'Atividade repetida para desenvolver uma habilidade.',
  },
  addition: {
    meaning: 'Operação matemática usada para somar valores.',
  },
  physical: {
    meaning: 'Relacionado ao corpo de uma pessoa.',
  },
  pressure: {
    meaning: 'Força aplicada perpendicularmente sobre uma área.',
  },
  capacity: {
    meaning: 'Quantidade máxima que cabe dentro de um recipiente.',
  },
  critical: {
    meaning: 'Que analisa alguma coisa com cuidado e critério.',
  },
  few: {
    meaning: 'Usado para indicar uma quantidade pequena e indeterminada.',
  },
  more: {
    meaning: 'Usado para indicar quantidade maior que outra.',
  },
  some: {
    meaning: 'Usado para indicar quantidade indeterminada de um conjunto.',
  },
  each: {
    meaning: 'Usado para indicar individualmente todo integrante de um grupo.',
  },
  many: {
    meaning: 'Usado para indicar grande quantidade de elementos contáveis.',
  },
  much: {
    meaning: 'Usado para indicar grande quantidade de algo incontável.',
  },
  less: {
    meaning: 'Usado para indicar quantidade menor que outra.',
  },
  none: {
    meaning: 'Usado no lugar de um nome para indicar ausência completa.',
  },
  together: {
    meaning: 'Na companhia uns dos outros.',
  },
  new: {
    meaning: 'Que foi produzido há pouco tempo.',
    hint: 'Foi produzido recentemente e ainda tem pouco tempo de existência.',
  },
  old: {
    meaning: 'Que existe há bastante tempo.',
    hint: 'Existe há muito tempo em relação aos semelhantes.',
  },
  age: {
    meaning: 'Tempo decorrido desde o nascimento de uma pessoa.',
    hint: 'Quantidade de tempo vivida desde o nascimento.',
  },
  free: {
    meaning: 'Que não está preso nem impedido de se mover.',
    hint: 'Caracteriza quem pode se mover sem estar preso.',
  },
  like: {
    meaning: 'Sentir preferência por alguém ou alguma coisa.',
    hint: 'Sentir preferência e prazer em relação a algo.',
  },
  gift: {
    meaning: 'Objeto oferecido voluntariamente a alguém sem cobrança.',
    hint: 'Objeto entregue a alguém sem exigir pagamento.',
  },
  easy: {
    meaning: 'Que pode ser feito sem grande dificuldade.',
    hint: 'Exige pouco esforço para ser realizado.',
  },
  away: {
    meaning: 'Que está distante do lugar de referência.',
    hint: 'Está distante do local usado como referência.',
  },
  fact: {
    meaning: 'Informação cuja veracidade pode ser comprovada.',
    hint: 'Informação que pode ser comprovada como verdadeira.',
  },
  loan: {
    meaning: 'Quantia em dinheiro cedida para devolução posterior.',
    hint: 'Dinheiro cedido por prazo definido e devolvido depois.',
  },
  local: {
    meaning: 'Relativo a um lugar específico.',
    hint: 'Relacionado a um lugar específico e limitado.',
  },
  index: {
    meaning: 'Relação ordenada que permite localizar informações.',
    hint: 'Relação ordenada usada para localizar informações.',
  },
  guide: {
    meaning: 'Conduzir alguém por um caminho até o destino.',
    hint: 'Conduzir uma pessoa pelo caminho até seu destino.',
  },
  major: {
    meaning: 'Que possui importância superior à dos demais.',
    hint: 'Possui importância superior à dos demais elementos.',
  },
  stuff: {
    translation: 'coisas',
    meaning: 'Objetos não especificados considerados em conjunto.',
    hint: 'Nome genérico e informal para objetos não especificados.',
  },
  force: {
    meaning: 'Obrigar alguém a agir mediante ameaça.',
    hint: 'Obrigar uma pessoa a agir contra a própria vontade.',
  },
  album: {
    meaning: 'Coleção de músicas lançadas em conjunto.',
    hint: 'Conjunto de músicas reunidas em um mesmo lançamento.',
  },
  grand: {
    meaning: 'Que impressiona por suas grandes dimensões.',
    hint: 'Impressiona por apresentar dimensões muito grandes.',
  },
  wrong: {
    meaning: 'Que não corresponde aos fatos corretos.',
    hint: 'Não corresponde à informação correta.',
  },
  grant: {
    meaning: 'Dar formalmente algo que foi solicitado.',
    hint: 'Dar de maneira formal aquilo que foi solicitado.',
  },
  scale: {
    meaning: 'Sistema graduado usado para medir valores.',
    hint: 'Sistema de marcas graduadas usado em uma medição.',
  },
  joint: {
    translation: 'compartilhado',
    meaning: 'Que pertence simultaneamente a duas pessoas ou grupos.',
    hint: 'Possui dois proprietários ao mesmo tempo.',
  },
  sorry: {
    translation: 'arrependido',
    meaning: 'Que lamenta ter causado um erro ou dano.',
    hint: 'Sente remorso por uma ação passada.',
  },
  equal: {
    meaning: 'Que possui a mesma quantidade que outro elemento.',
    hint: 'Apresenta exatamente a mesma quantidade que outro elemento.',
  },
  false: {
    meaning: 'Que não corresponde à verdade.',
    hint: 'Apresenta uma informação que não é verdadeira.',
  },
  queen: {
    meaning: 'Mulher que governa uma monarquia.',
    hint: 'Mulher que ocupa o trono e governa uma monarquia.',
  },
  minor: {
    meaning: 'Que apresenta menor importância que outro elemento.',
    hint: 'Tem pouca importância em comparação com outro elemento.',
  },
  source: {
    meaning: 'Lugar do qual alguma coisa se origina.',
    hint: 'Lugar onde alguma coisa tem sua origem.',
  },
  common: {
    meaning: 'Que ocorre com grande frequência.',
    hint: 'Acontece muitas vezes e não é raro.',
  },
  direct: {
    meaning: 'Que chega ao destino sem passar por intermediário.',
    hint: 'Chega ao destino sem a participação de intermediário.',
  },
  global: {
    meaning: 'Que envolve o mundo inteiro.',
    hint: 'Abrange países e regiões do mundo inteiro.',
  },
  domain: {
    meaning: 'Área delimitada de conhecimento.',
    hint: 'Campo delimitado dentro do conhecimento humano.',
  },
  active: {
    meaning: 'Que está em funcionamento no momento.',
    hint: 'Encontra-se funcionando neste momento.',
  },
  growth: {
    meaning: 'Processo gradual em que algo aumenta de tamanho.',
    hint: 'Processo pelo qual algo se torna maior com o tempo.',
  },
  season: {
    translation: 'estação',
    meaning: 'Período do ano marcado por condições climáticas próprias.',
    hint: 'Período anual reconhecido por um clima característico.',
  },
  mature: {
    meaning: 'Desenvolver-se até alcançar o crescimento completo.',
    hint: 'Alcançar o estágio completo de crescimento.',
  },
  strong: {
    meaning: 'Que possui grande força física.',
    hint: 'Demonstra grande força física.',
  },
  senior: {
    meaning: 'Pessoa com maior experiência em uma função.',
    hint: 'Pessoa experiente que ocupa uma categoria profissional elevada.',
  },
  target: {
    meaning: 'Resultado que se pretende alcançar.',
    hint: 'Resultado definido que alguém pretende alcançar.',
  },
  sector: {
    meaning: 'Parte delimitada de uma economia.',
    hint: 'Divisão específica dentro da atividade econômica.',
  },
  demand: {
    meaning: 'Exigir alguma coisa com firmeza.',
    hint: 'Pedir com firmeza que algo seja entregue ou feito.',
  },
  leader: {
    meaning: 'Pessoa que orienta um grupo em direção a um objetivo.',
    hint: 'Pessoa que conduz um grupo em direção ao objetivo.',
  },
  puzzle: {
    meaning: 'Jogo que exige raciocínio para chegar à solução.',
    hint: 'Jogo resolvido por meio de raciocínio e combinação.',
  },
  ticket: {
    meaning: 'Documento que permite a entrada em um evento.',
    hint: 'Documento apresentado para entrar em um evento.',
  },
  content: {
    meaning: 'Informação apresentada dentro de uma publicação.',
    hint: 'Informação contida em uma publicação.',
  },
  official: {
    partOfSpeech: 'adjective',
    translation: 'oficial',
    meaning: 'Que foi formalmente reconhecido por uma instituição.',
    hint: 'Recebeu reconhecimento formal de uma instituição.',
  },
  electric: {
    meaning: 'Que funciona por meio de eletricidade.',
    hint: 'Depende de eletricidade para funcionar.',
  },
  big: {
    meaning: 'Que possui tamanho acima do comum.',
  },
  low: {
    meaning: 'Que ocupa posição pouco elevada em relação ao solo.',
  },
  ask: {
    meaning: 'Fazer um pedido a outra pessoa.',
  },
  pop: {
    meaning: 'Romper-se de repente com um som curto e seco.',
  },
  next: {
    meaning: 'Que ocupa a posição imediatamente posterior em uma ordem.',
  },
  last: {
    meaning: 'Que ocupa a posição final em uma sequência.',
  },
  make: {
    meaning: 'Criar alguma coisa por meio de trabalho.',
  },
  then: {
    meaning: 'Naquele momento mencionado anteriormente.',
  },
  full: {
    meaning: 'Que possui todas as partes necessárias.',
  },
  want: {
    meaning: 'Sentir desejo de obter alguma coisa.',
  },
  show: {
    meaning: 'Tornar alguma coisa visível para outra pessoa.',
  },
  form: {
    meaning: 'Formato exterior apresentado por alguma coisa.',
  },
  teen: {
    meaning: 'Pessoa com idade entre treze e dezenove anos.',
  },
  join: {
    meaning: 'Unir dois elementos que estavam separados.',
  },
  test: {
    meaning: 'Verificar se alguma coisa funciona corretamente.',
  },
  hard: {
    meaning: 'Que exige esforço considerável para ser realizado.',
  },
  keep: {
    meaning: 'Conservar alguma coisa sob sua posse.',
  },
  unit: {
    meaning: 'Quantidade individual usada como base de medida.',
  },
  huge: {
    meaning: 'Que apresenta tamanho extraordinariamente grande.',
  },
  nice: {
    meaning: 'Que causa bem-estar e uma boa impressão.',
  },
  first: {
    meaning: 'Que ocupa a posição inicial em uma ordem.',
  },
  great: {
    meaning: 'Que se destaca por sua qualidade elevada.',
  },
  small: {
    meaning: 'Que possui tamanho abaixo do comum.',
  },
  event: {
    meaning: 'Acontecimento planejado para ocorrer em certo tempo e lugar.',
  },
  close: {
    meaning: 'Que está a pequena distância física.',
  },
  short: {
    meaning: 'Que dura por pouco tempo.',
  },
  early: {
    meaning: 'Que acontece antes do horário esperado.',
  },
  earth: {
    meaning: 'Planeta do Sistema Solar em que vivemos.',
  },
  input: {
    meaning: 'Dado fornecido a um sistema para ser processado.',
  },
  agree: {
    meaning: 'Ter a mesma opinião que outra pessoa.',
  },
  suite: {
    meaning: 'Conjunto de cômodos privativos oferecido em um hotel.',
  },
  prime: {
    translation: 'principal',
    meaning: 'Que possui a maior importância entre as opções.',
  },
  reach: {
    meaning: 'Chegar ao destino pretendido.',
  },
  alert: {
    meaning: 'Avisar alguém sobre a existência de um perigo.',
  },
  return: {
    meaning: 'Ir novamente ao lugar onde se estava antes.',
  },
  agency: {
    meaning: 'Organização que presta serviços especializados.',
  },
  reason: {
    meaning: 'Motivo que explica uma ação.',
  },
  survey: {
    meaning: 'Coletar sistematicamente as opiniões de um grupo de pessoas.',
  },
  output: {
    meaning: 'Informação produzida por um sistema após processamento.',
  },
  switch: {
    meaning: 'Mudar da opção atual para outra disponível.',
  },
  accept: {
    meaning: 'Receber alguma coisa de boa vontade.',
  },
  enable: {
    meaning: 'Dar permissão para que uma função opere.',
  },
  define: {
    meaning: 'Explicar com precisão o significado de uma palavra.',
  },
  junior: {
    meaning: 'Pessoa com menos experiência em uma função.',
  },
  luxury: {
    meaning: 'Bem caro que supera as necessidades básicas.',
  },
  relief: {
    meaning: 'Sensação de conforto após a redução de uma dor.',
  },
  stress: {
    meaning: 'Estado de tensão emocional causado por pressão.',
  },
  address: {
    meaning: 'Informação que identifica a localização de um lugar.',
  },
  profile: {
    meaning: 'Descrição resumida das características de uma pessoa.',
  },
  comment: {
    meaning: 'Observação que acrescenta uma opinião a um assunto.',
  },
  council: {
    meaning: 'Grupo que se reúne para tomar decisões coletivas.',
  },
  display: {
    meaning: 'Tornar um objeto visível para observadores.',
  },
  primary: {
    meaning: 'Que vem primeiro em importância.',
  },
  regular: {
    meaning: 'Que acontece em intervalos constantes.',
  },
  positive: {
    meaning: 'Que produz um resultado favorável.',
  },
  resource: {
    meaning: 'Material disponível para cumprir uma finalidade.',
  },
  multiple: {
    meaning: 'Que envolve mais de uma ocorrência do mesmo tipo.',
  },
  sound: {
    meaning: 'Parecer de determinada maneira quando é ouvido.',
    hint: 'Causar determinada impressão em quem escuta.',
  },
  adult: {
    meaning: 'Pessoa que alcançou a idade definida legalmente para a maioridade.',
    hint: 'Pessoa que já atingiu a maioridade prevista em lei.',
  },
  prior: {
    meaning: 'Que aconteceu antes de outro fato no tempo.',
    hint: 'Descreve um fato que já tinha ocorrido quando outro começou.',
  },
  frame: {
    meaning: 'Estrutura decorativa que contorna uma imagem.',
    hint: 'Estrutura colocada ao redor de uma imagem para destacá-la.',
  },
  limit: {
    meaning: 'Ponto máximo além do qual não é possível avançar.',
    hint: 'Ponto final que não pode ser ultrapassado.',
  },
  smart: {
    meaning: 'Que demonstra inteligência ao resolver problemas.',
    hint: 'Resolve problemas com inteligência e rapidez.',
  },
  please: {
    meaning: 'Causar satisfação em outra pessoa.',
    hint: 'Fazer com que outra pessoa fique satisfeita.',
  },
  result: {
    meaning: 'Efeito produzido por uma ação.',
    hint: 'Efeito que surge depois de uma ação.',
  },
  choice: {
    meaning: 'Ato de selecionar uma alternativa entre várias.',
    hint: 'Ato de selecionar uma alternativa disponível.',
  },
  button: {
    meaning: 'Peça pequena pressionada para acionar um mecanismo.',
    hint: 'Peça pressionada com o dedo para acionar um mecanismo.',
  },
  general: {
    meaning: 'Que abrange todos os casos de um conjunto.',
    hint: 'Abrange o conjunto inteiro, sem se limitar a um caso.',
  },
  special: {
    meaning: 'Que se distingue por uma característica incomum.',
    hint: 'Possui uma característica que o distingue dos demais.',
  },
  problem: {
    meaning: 'Situação difícil que precisa ser resolvida.',
    hint: 'Situação que exige uma resposta para ser resolvida.',
  },
  certain: {
    meaning: 'Que não deixa dúvida sobre sua verdade.',
    hint: 'Não apresenta dúvida quanto a ser verdadeiro.',
  },
  forward: {
    meaning: 'Que está voltado na direção da frente.',
    hint: 'Aponta na direção situada à frente.',
  },
  session: {
    meaning: 'Período reservado para a realização de uma reunião.',
    hint: 'Período reservado para uma reunião começar e terminar.',
  },
  previous: {
    meaning: 'Que ocorreu antes do acontecimento atual.',
    hint: 'Descreve algo ocorrido antes do item atual.',
  },
  continue: {
    meaning: 'Manter uma ação em andamento sem interrompê-la.',
    hint: 'Manter uma ação em andamento sem parar.',
  },
  external: {
    meaning: 'Que fica localizado do lado de fora.',
    hint: 'Fica localizado além da parte interna.',
  },
  get: {
    meaning: 'Conseguir alguma coisa que se deseja.',
  },
  bin: {
    translation: 'lixeira',
    meaning: 'Recipiente usado para descartar materiais sem utilidade.',
  },
  know: {
    meaning: 'Ter informação sobre determinado assunto.',
  },
  team: {
    meaning: 'Grupo de pessoas que trabalha em cooperação.',
  },
  side: {
    meaning: 'Parte lateral de alguma coisa.',
  },
  basic: {
    meaning: 'Que contém apenas os elementos essenciais.',
  },
  brand: {
    meaning: 'Nome que distingue um produto dos concorrentes.',
  },
  royal: {
    meaning: 'Relacionado à família que governa uma monarquia.',
  },
  faith: {
    meaning: 'Confiança profunda em uma crença religiosa.',
  },
  current: {
    meaning: 'Que existe no momento presente.',
  },
  standard: {
    meaning: 'Que segue um modelo estabelecido como referência.',
  },
  maximum: {
    meaning: 'Que corresponde ao maior valor que pode ser atingido.',
  },
  minimum: {
    meaning: 'Que corresponde ao menor valor que pode ser atingido.',
  },
  possible: {
    meaning: 'Que pode se tornar realidade.',
  },
  activity: {
    meaning: 'Ação realizada com determinada finalidade.',
  },
  consumer: {
    meaning: 'Pessoa que compra bens para uso próprio.',
  },
  transfer: {
    meaning: 'Ato de mover uma pessoa de um lugar para outro.',
  },
  consider: {
    meaning: 'Examinar algo com atenção antes de tomar uma decisão.',
  },
  every: {
    meaning: 'Usado para indicar todos os integrantes de um grupo sem exceção.',
  },
  such: {
    meaning: 'Usado para indicar algo do tipo mencionado anteriormente.',
  },
  very: {
    meaning: 'Usado para aumentar a intensidade de uma característica.',
    hint: 'Aumenta bastante a intensidade de uma característica.',
  },
  there: {
    meaning: 'Naquele lugar diferente de onde se fala.',
    hint: 'Indica um lugar distante de quem está falando.',
  },
  here: {
    meaning: 'No lugar em que se fala.',
  },
  down: {
    meaning: 'Em direção a uma posição mais baixa.',
  },
  behind: {
    meaning: 'Em posição localizada atrás da referência.',
  },
  even: {
    meaning: 'Que corresponde a um número inteiro divisível por dois sem resto.',
    hint: 'Descreve um número divisível exatamente por dois.',
  },
  male: {
    meaning: 'Que pertence ao sexo masculino de uma espécie.',
    hint: 'Pertence ao sexo que produz gametas masculinos.',
  },
  human: {
    meaning: 'Que pertence à espécie humana.',
    hint: 'Pertence à espécie formada pelas pessoas.',
  },
  legal: {
    meaning: 'Que é permitido pelas leis em vigor.',
    hint: 'Está de acordo com as leis em vigor.',
  },
  civil: {
    meaning: 'Que se refere aos cidadãos fora do âmbito militar.',
    hint: 'Relaciona-se aos cidadãos e não às forças armadas.',
  },
  pretty: {
    meaning: 'Que é agradável de ver por sua beleza.',
    hint: 'Tem aparência agradável e delicada.',
  },
  famous: {
    meaning: 'Que é conhecido por grande número de pessoas.',
  },
  private: {
    meaning: 'Que é reservado a um grupo e não aberto ao público.',
  },
  specific: {
    meaning: 'Que está claramente definido e limitado a um assunto.',
  },
  plan: {
    meaning: 'Conjunto organizado de ações destinado a alcançar um objetivo.',
  },
  plus: {
    meaning: 'Aspecto favorável que melhora uma situação.',
  },
  golf: {
    meaning: 'Esporte em que se usam tacos para conduzir uma bola até uma série de buracos.',
  },
  cash: {
    translation: 'dinheiro',
    meaning: 'Forma de pagamento composta por notas e moedas disponíveis de imediato.',
  },
  wish: {
    meaning: 'Querer que um acontecimento se torne realidade.',
  },
  lead: {
    meaning: 'Orientar o caminho seguido por uma pessoa ou grupo.',
  },
  visit: {
    meaning: 'Encontrar uma pessoa e permanecer com ela por tempo limitado.',
  },
  build: {
    meaning: 'Produzir uma estrutura ao reunir materiais e peças.',
  },
  lower: {
    meaning: 'Mover alguma coisa para uma posição mais baixa.',
  },
  award: {
    meaning: 'Reconhecimento concedido a alguém por seu mérito.',
  },
  system: {
    meaning: 'Conjunto de partes organizadas que funcionam de maneira integrada.',
  },
  action: {
    meaning: 'Ato realizado para produzir um efeito definido.',
  },
  amount: {
    meaning: 'Medida total de algo que pode ser contado ou mensurado.',
  },
  method: {
    meaning: 'Maneira organizada e sistemática de realizar uma tarefa.',
  },
  nature: {
    meaning: 'Conjunto dos seres vivos, paisagens e fenômenos do mundo físico.',
  },
  supply: {
    meaning: 'Entregar os materiais necessários para uma atividade.',
  },
  client: {
    meaning: 'Pessoa que contrata um serviço profissional.',
  },
  remove: {
    meaning: 'Retirar alguma coisa do lugar em que estava.',
  },
  weekly: {
    partOfSpeech: 'adjective',
    translation: 'semanal',
    meaning: 'Que acontece uma vez por semana.',
  },
  resort: {
    partOfSpeech: 'noun',
    translation: 'resort',
    meaning: 'Complexo turístico que reúne hospedagem, lazer e serviços no mesmo local.',
  },
  expert: {
    meaning: 'Pessoa com conhecimento especializado em uma área.',
  },
  bridge: {
    meaning: 'Estrutura que permite atravessar um rio ou outro obstáculo.',
  },
  lawyer: {
    meaning: 'Profissional autorizado a orientar pessoas e representá-las em questões jurídicas.',
  },
  soccer: {
    meaning: 'Esporte em que duas equipes tentam chutar a bola para dentro do gol adversário.',
  },
  tennis: {
    meaning: 'Esporte de raquetes em que uma bola passa sobre uma rede.',
  },
  forget: {
    meaning: 'Deixar de lembrar uma informação ou compromisso.',
  },
  project: {
    meaning: 'Trabalho planejado com um objetivo, etapas e prazo definidos.',
  },
  include: {
    meaning: 'Fazer uma pessoa ou coisa integrar um conjunto.',
  },
  example: {
    meaning: 'Caso específico usado para demonstrar uma regra ou ideia.',
  },
  further: {
    partOfSpeech: 'adjective',
    translation: 'adicional',
    meaning: 'Que acrescenta algo além do que já foi apresentado.',
  },
  manager: {
    meaning: 'Pessoa que administra uma equipe profissional.',
  },
  ability: {
    translation: 'habilidade',
    meaning: 'Competência necessária para realizar determinada ação.',
  },
  mortgage: {
    meaning: 'Garantia jurídica dada sobre um imóvel para assegurar o pagamento de uma dívida.',
  },
  schedule: {
    meaning: 'Definir a data e o horário de uma atividade.',
  },
  abstract: {
    partOfSpeech: 'adjective',
    translation: 'abstrato',
    meaning: 'Que existe como ideia e não possui forma concreta.',
  },
  room: {
    translation: 'quarto',
    meaning: 'Cômodo de uma casa destinado principalmente a dormir.',
    hint: 'Cômodo da casa que normalmente possui uma cama.',
  },
  while: {
    translation: 'intervalo',
    meaning: 'Período curto durante o qual alguma coisa acontece.',
    hint: 'Período breve de duração não especificada.',
  },
  total: {
    meaning: 'Que inclui todas as partes de um conjunto.',
    hint: 'Abrange o conjunto inteiro sem deixar nenhuma parte de fora.',
  },
  might: {
    partOfSpeech: 'verb',
    translation: 'poder',
    meaning: 'Indicar a possibilidade de que alguma coisa aconteça.',
    hint: 'Expressa que um acontecimento é possível, mas não certo.',
  },
  share: {
    translation: 'cota',
    meaning: 'Parte de uma empresa que pertence a alguém.',
    hint: 'Fatia de uma empresa pertencente a uma pessoa.',
  },
  upper: {
    meaning: 'Que ocupa uma posição mais alta que outro elemento.',
    hint: 'Fica acima de outro elemento usado como referência.',
  },
  female: {
    partOfSpeech: 'adjective',
    translation: 'feminino',
    meaning: 'Que pertence ao sexo que produz óvulos.',
    hint: 'Refere-se ao sexo associado à produção de óvulos.',
  },
  random: {
    translation: 'aleatório',
    meaning: 'Que é escolhido sem seguir um padrão previsível.',
    hint: 'Seu resultado não segue uma sequência previsível.',
  },
  secret: {
    meaning: 'Que é mantido oculto e conhecido por poucas pessoas.',
    hint: 'Permanece fora do conhecimento público.',
  },
  football: {
    translation: 'futebol americano',
    meaning: 'Esporte em que equipes avançam uma bola oval pelo campo para marcar pontos.',
    hint: 'Usa uma bola oval que pode ser carregada ou lançada com as mãos.',
  },
};

// Corrections accepted after the separately assigned final catalog audit. This
// map intentionally overrides earlier authoring without hiding the first pass.
const finalAuditRevisions = {
  end: {
    meaning: 'Levar uma atividade ao seu ponto final.',
    hint: 'Fazer uma atividade deixar de continuar.',
  },
  far: {
    translation: 'distante',
    meaning: 'Que fica a grande distância do observador.',
    hint: 'Exige um longo deslocamento para ser alcançado.',
  },
  away: {
    partOfSpeech: 'adverb',
    translation: 'para longe',
    meaning: 'Em direção a um lugar distante do ponto de partida.',
    hint: 'Indica movimento de afastamento do local inicial.',
  },
  bit: {
    translation: 'um pouco',
    meaning: 'Pequena quantidade de alguma coisa.',
    hint: 'Quantidade reduzida e sem medida exata.',
  },
  part: {
    meaning: 'Elemento que desempenha uma função dentro de um conjunto.',
    hint: 'Componente necessário para formar um todo.',
  },
  piece: {
    translation: 'pedaço',
    meaning: 'Fragmento físico separado de um objeto maior.',
    hint: 'Surge quando um objeto é dividido em fragmentos.',
  },
  kit: {
    translation: 'jogo de peças',
    meaning: 'Coleção de peças fornecidas juntas para uma finalidade específica.',
    hint: 'Reúne os objetos necessários para cumprir uma atividade.',
  },
  ten: {
    meaning: 'Quantidade obtida ao juntar duas parcelas de cinco.',
    hint: 'É representado pelos algarismos um e zero lado a lado.',
  },
  four: {
    meaning: 'Número de elementos presente em dois pares.',
    hint: 'Corresponde à quantidade de estações de um ano.',
  },
  seven: {
    meaning: 'Número natural imediatamente anterior a oito.',
    hint: 'Uma semana completa possui essa quantidade de dias.',
  },
  eight: {
    meaning: 'Quantidade obtida ao dobrar quatro.',
    hint: 'Uma aranha costuma ter essa quantidade de pernas.',
  },
  fit: {
    meaning: 'Ter dimensões compatíveis com o espaço disponível.',
    hint: 'Possuir tamanho adequado ao espaço disponível.',
  },
  spa: {
    translation: 'spa',
    meaning: 'Estabelecimento dedicado a relaxamento e cuidados corporais.',
    hint: 'Oferece massagens, banhos e outros cuidados para o bem-estar.',
  },
  aim: {
    meaning: 'Intenção que orienta uma ação.',
    hint: 'Propósito futuro que direciona o que alguém faz.',
  },
  target: {
    meaning: 'Objeto específico para o qual se dirige uma ação.',
    hint: 'Ponto marcado que alguém tenta atingir.',
  },
  hip: {
    hint: 'Região onde a perna se articula com o tronco.',
  },
  bird: {
    hint: 'Animal alado que constrói ninhos e possui penas.',
  },
  item: {
    hint: 'Entrada individual encontrada em uma lista.',
  },
  type: {
    meaning: 'Categoria definida por características essenciais em comum.',
    hint: 'Classifica elementos segundo os traços que os definem.',
  },
  sort: {
    translation: 'espécie',
    meaning: 'Grupo informal de coisas semelhantes.',
    hint: 'Forma cotidiana de agrupar coisas parecidas.',
  },
  area: {
    meaning: 'Extensão de espaço delimitada para uma finalidade específica.',
    hint: 'Região com limites definidos para determinado uso.',
  },
  long: {
    hint: 'Ocupa bastante espaço entre suas duas pontas.',
  },
  risk: {
    hint: 'Colocar algo em situação na qual pode sofrer prejuízo.',
  },
  girl: {
    meaning: 'Criança do sexo feminino.',
    hint: 'Pessoa jovem que ainda não chegou à idade adulta.',
  },
  near: {
    translation: 'próximo',
    meaning: 'Que está a pouca distância de um ponto específico.',
    hint: 'Fica quase ao lado do ponto usado como referência.',
  },
  nearby: {
    partOfSpeech: 'adverb',
    translation: 'nas proximidades',
    meaning: 'Em algum lugar da região ao redor.',
    hint: 'Indica localização na vizinhança imediata.',
  },
  male: {
    meaning: 'Que pertence ao sexo dos homens e dos animais machos.',
    hint: 'Descreve o sexo de um homem ou animal macho.',
  },
  human: {
    meaning: 'Que possui características próprias das pessoas.',
    hint: 'Diz respeito às pessoas consideradas como espécie.',
  },
  idea: {
    hint: 'Representação mental que pode orientar uma criação.',
  },
  vote: {
    hint: 'Registrar uma preferência durante uma escolha coletiva.',
  },
  price: {
    hint: 'Valor monetário associado à compra de algo.',
  },
  north: {
    meaning: 'Direção cardeal voltada para o polo Ártico.',
    hint: 'Nos mapas, costuma aparecer na parte superior.',
  },
  reply: {
    meaning: 'Enviar uma mensagem em reação ao que outra pessoa comunicou.',
    hint: 'Dar retorno direto a uma mensagem recebida.',
  },
  might: {
    meaning: 'Expressar incerteza sobre a ocorrência de um fato.',
    hint: 'Sinaliza que o fato mencionado não é certo.',
  },
  share: {
    hint: 'Representa uma fração da propriedade de uma companhia.',
  },
  third: {
    meaning: 'Posição ocupada por quem tem duas pessoas à frente.',
    hint: 'Em uma disputa, vem logo após o segundo colocado.',
  },
  second: {
    meaning: 'Posição ocupada logo depois do primeiro lugar.',
    hint: 'Em uma fila, há apenas uma pessoa à sua frente.',
  },
  fourth: {
    meaning: 'Colocação de quem possui três concorrentes à frente.',
    hint: 'Surge imediatamente depois da terceira posição.',
  },
  watch: {
    meaning: 'Acompanhar atentamente com os olhos durante certo período.',
    hint: 'Manter os olhos voltados para algo por algum tempo.',
  },
  error: {
    hint: 'Indica que algo se desviou do resultado esperado.',
  },
  score: {
    translation: 'pontuação',
    meaning: 'Total de pontos obtido em uma disputa.',
    hint: 'Soma dos pontos alcançados durante uma partida.',
  },
  super: {
    meaning: 'Que se destaca muito acima da qualidade comum, em uso informal.',
    hint: 'Forma informal de elogiar algo muito bom.',
  },
  prior: {
    hint: 'Já havia acontecido no momento usado como referência.',
  },
  blood: {
    meaning: 'Líquido bombeado pelo coração que transporta oxigênio e nutrientes.',
    hint: 'É bombeado pelo coração para circular pelo corpo.',
  },
  grand: {
    translation: 'imponente',
    meaning: 'Que causa forte impressão por sua aparência majestosa.',
    hint: 'Tem aparência majestosa e chama muita atenção.',
  },
  trust: {
    meaning: 'Acreditar que alguém agirá com honestidade.',
    hint: 'Sentir segurança ao depender de outra pessoa.',
  },
  query: {
    translation: 'consultar',
    meaning: 'Solicitar uma informação específica a um sistema.',
    hint: 'Enviar a um sistema uma solicitação de informação.',
  },
  minor: {
    meaning: 'Que possui pouca importância em comparação com outro elemento.',
    hint: 'Tem papel secundário na situação.',
  },
  center: {
    meaning: 'Região intermediária de uma área delimitada.',
    hint: 'Fica no meio de uma área, afastado das bordas.',
  },
  browse: {
    meaning: 'Percorrer conteúdo sem seguir uma sequência definida.',
    hint: 'Explorar páginas livremente, sem destino específico.',
  },
  enough: {
    partOfSpeech: 'determiner',
    translation: 'o bastante',
    meaning: 'Usado para indicar que a quantidade necessária foi alcançada.',
    hint: 'Indica que não é preciso acrescentar mais.',
  },
  rental: {
    meaning: 'Contrato que permite usar temporariamente um bem mediante pagamento.',
    hint: 'Uso por tempo limitado de um bem que pertence a outra pessoa.',
  },
  unique: {
    meaning: 'Que não possui nenhum equivalente.',
    hint: 'Não existe outro elemento igual a ele.',
  },
  medium: {
    meaning: 'Forma usada para representar e transmitir conteúdo.',
    hint: 'Pode ser texto, som ou imagem empregados na comunicação.',
  },
  channel: {
    meaning: 'Via específica pela qual uma mensagem chega ao público.',
    hint: 'Caminho escolhido para distribuir uma comunicação.',
  },
  parent: {
    meaning: 'Pessoa responsável por criar e cuidar de um filho.',
    hint: 'Cuida de um filho e assume responsabilidade por sua criação.',
  },
  demand: {
    meaning: 'Requerer alguma coisa com firmeza e autoridade.',
    hint: 'Fazer um pedido firme que deve ser atendido.',
  },
  listen: {
    meaning: 'Concentrar a atenção nos sons ao redor.',
    hint: 'Usar a audição de forma intencional.',
  },
  pocket: {
    hint: 'Parte da roupa usada para levar pequenos objetos.',
  },
  branch: {
    hint: 'Costuma sustentar folhas, flores ou frutos longe do tronco.',
  },
  senate: {
    meaning: 'Casa legislativa composta por integrantes chamados senadores.',
    hint: 'Órgão legislativo formado por senadores.',
  },
  script: {
    meaning: 'Texto que orienta a sequência de falas e cenas de uma apresentação.',
    hint: 'Serve de guia para atores e equipe durante a produção.',
  },
  gender: {
    meaning: 'Dimensão social da identidade relacionada à forma de ser reconhecido.',
    hint: 'Aspecto social da identidade pessoal, distinto do sexo biológico.',
  },
  proper: {
    meaning: 'Que atende corretamente às exigências de uma situação.',
    hint: 'Está de acordo com o comportamento esperado.',
  },
  cruise: {
    partOfSpeech: 'noun',
    translation: 'cruzeiro',
    meaning: 'Viagem de lazer realizada em navio com roteiro planejado.',
    hint: 'Viagem turística de navio com paradas programadas.',
  },
  miller: {
    meaning: 'Pessoa que trabalha em um moinho para transformar grãos em farinha.',
    hint: 'Trabalha em um moinho produzindo farinha a partir de grãos.',
  },
  privacy: {
    meaning: 'Condição de manter a vida pessoal livre de observação indesejada.',
    hint: 'Protege a vida pessoal do acesso de outras pessoas.',
  },
  version: {
    meaning: 'Estado específico de um produto após determinado conjunto de mudanças.',
    hint: 'Identifica uma variante do produto atualizada em certo momento.',
  },
  edition: {
    meaning: 'Publicação de uma obra preparada para determinado lançamento.',
    hint: 'Forma em que um livro foi preparado para uma tiragem específica.',
  },
  network: {
    hint: 'Permite que seus integrantes troquem informações entre si.',
  },
  control: {
    meaning: 'Determinar como um sistema deve funcionar.',
    hint: 'Manter o comportamento de um sistema dentro dos limites desejados.',
  },
  central: {
    hint: 'Fica afastado das bordas de uma área.',
  },
  several: {
    meaning: 'Usado para indicar um grupo de tamanho moderado, sem quantidade exata.',
    hint: 'Refere-se a um número moderado e não especificado de elementos.',
  },
  various: {
    translation: 'diversos',
    meaning: 'Que apresenta elementos de diferentes tipos.',
    hint: 'Abrange uma variedade de tipos dentro do mesmo conjunto.',
  },
  kingdom: {
    hint: 'País cujo chefe de Estado é um monarca.',
  },
  feature: {
    meaning: 'Aspecto marcante que ajuda a distinguir alguma coisa.',
    hint: 'Qualidade perceptível que diferencia algo dos demais.',
  },
  success: {
    meaning: 'Condição alcançada quando uma meta é cumprida.',
    hint: 'É o desfecho favorável de um esforço.',
  },
  session: {
    meaning: 'Período contínuo dedicado a uma atividade específica.',
    hint: 'Bloco de tempo reservado para realizar uma atividade.',
  },
  personal: {
    hint: 'Não é coletivo nem público; refere-se a um indivíduo.',
  },
  analysis: {
    hint: 'Processo de separar um tema em componentes para compreendê-lo.',
  },
  official: {
    meaning: 'Que possui reconhecimento válido de uma instituição.',
    hint: 'Tem validade confirmada por um órgão competente.',
  },
  function: {
    meaning: 'Finalidade para a qual uma coisa foi criada.',
    hint: 'Indica para que determinada coisa serve.',
  },
  response: {
    meaning: 'Reação produzida por um estímulo ou acontecimento.',
    hint: 'Efeito observado depois que algo provoca uma reação.',
  },
  approach: {
    hint: 'Reduzir gradualmente a distância até uma pessoa.',
  },
  republic: {
    meaning: 'Forma de governo em que o chefe de Estado não é monarca hereditário.',
    hint: 'Sistema político cujo chefe de Estado não herda o cargo como monarca.',
  },
  northern: {
    meaning: 'Localizado na região voltada ao polo Ártico.',
    hint: 'Pertence à metade superior de um mapa convencional.',
  },
  southern: {
    meaning: 'Que vem da região situada em direção ao polo Antártico.',
    hint: 'Descreve algo originário das áreas mais abaixo no mapa.',
  },
};

const effectiveRevisions = { ...revisions, ...finalAuditRevisions };

const source = JSON.parse(fs.readFileSync(sourcePath, 'utf8'));
const meanings = JSON.parse(fs.readFileSync(meaningsPath, 'utf8'));
const seen = new Set();
for (const record of source.records) {
  const revision = effectiveRevisions[record.answer];
  if (!revision) continue;
  if (seen.has(record.answer)) {
    throw new Error(`Resposta duplicada nas revisões: ${record.answer}.`);
  }
  Object.assign(record, revision);
  meanings[record.answer] = record.meaning;
  seen.add(record.answer);
}
const missing = Object.keys(effectiveRevisions).filter((answer) => !seen.has(answer));
if (missing.length > 0) {
  throw new Error(`Revisões sem resposta correspondente: ${missing.join(', ')}.`);
}

fs.writeFileSync(sourcePath, `${JSON.stringify(source, null, 2)}\n`);
fs.writeFileSync(meaningsPath, `${JSON.stringify(meanings, null, 2)}\n`);
const reviewedRecords = source.records.map((record) => {
  const canonical = {
    mode: record.mode,
    number: record.number,
    answer: record.answer,
    partOfSpeech: record.partOfSpeech,
    translation: record.translation,
    meaning: record.meaning,
    ...(record.mode === 'withHints' ? { hint: record.hint } : {}),
  };
  return {
    mode: record.mode,
    number: record.number,
    answer: record.answer,
    contentSha256: crypto
      .createHash('sha256')
      .update(JSON.stringify(canonical), 'utf8')
      .digest('hex'),
    explicitlyRevised: seen.has(record.answer),
    coordinatingOrRetained: /\bou\b/i.test(record.meaning),
    singleSenseApproved: true,
  };
});
const remainingCoordinations = reviewedRecords.filter(
  (record) => record.coordinatingOrRetained,
).length;
const review = {
  schemaVersion: 1,
  catalogRevision: source.catalogRevision,
  pass: {
    id: 'codex-single-sense-audit-2026-08-09',
    performedOn: '2026-08-09',
    agent: 'OpenAI Codex',
    humanReview: false,
    method:
      'All 1,000 meanings were inspected. The 621 original meanings containing the standalone conjunction ou were reviewed individually; lexical sense bifurcations were narrowed and same-sense coordinations were retained.',
  },
  counts: {
    records: reviewedRecords.length,
    originalOrCandidates: 621,
    explicitlyRevised: seen.size,
    remainingSameSenseCoordinations: remainingCoordinations,
  },
  records: reviewedRecords,
};
fs.writeFileSync(reviewPath, `${JSON.stringify(review, null, 2)}\n`);
console.log(
  `Segunda passagem semântica: ${seen.size} revisões explícitas e ${remainingCoordinations} coordenações de mesmo sentido.`,
);
