# Respostas prontas para a Google Play Console — PalavraX 1.0.0

Documento conferido em 12 de agosto de 2026. Ele descreve exatamente o binário
`com.lexinexo.app`, versão `1.0.0` (código 1). Reconfirme as respostas quando o
aplicativo ganhar novas funções, SDKs, permissões, anúncios ou serviços online.

## 1. Campos que já estão definidos

| Campo da Play Console | Resposta |
|---|---|
| Idioma padrão | Português (Brasil) — `pt-BR` |
| Nome do app | `PalavraX: Aprenda Inglês` |
| App ou jogo | Jogo |
| Gratuito ou pago | Gratuito |
| Nome do pacote | `com.lexinexo.app` |
| Categoria | Jogos → Palavras |
| País inicial | Brasil |
| Disponibilidade | Somente celular e tablet Android no Brasil |
| Versão | `1.0.0` |
| Código da versão | `1` |
| Público-alvo | 13–15, 16–17 e 18 anos ou mais |
| Anúncios | Não contém anúncios |
| Compras e assinaturas | Não possui |
| Login ou conta | Não possui |
| Funcionamento | Totalmente offline |

O package é exclusivo e permanente depois do primeiro upload. Não crie outro
aplicativo na Console com package diferente e não altere `com.lexinexo.app`.

## 2. Dados que o titular precisa fornecer

Preencha o schema v2 de `play_store/publication_metadata.json` no
repositório-fonte ou `owner-action/publication_metadata.json` no pacote extraído
com dados reais. Não use os exemplos do template.

Se ainda não existir uma conta Play Console, o titular precisa ter pelo menos
18 anos, criar a conta e pagar a taxa única de cadastro exibida pela Google
(atualmente US$ 25). A cobrança é da conta, não deste aplicativo.

| Campo | Situação |
|---|---|
| Nome público do desenvolvedor/estúdio | **PREENCHER COM DADO REAL** |
| Tipo da conta: pessoal ou organização | **CONFIRMAR NA CONTA** |
| Nome legal e endereço | **PREENCHER NA CONTA** |
| E-mail público de suporte | **PREENCHER E VERIFICAR** |
| E-mail de privacidade | **PREENCHER E VERIFICAR** |
| E-mail e telefone privados da conta | **PREENCHER E VERIFICAR NA CONTA** |
| Telefone público de suporte da ficha | **OPCIONAL; `supportPhone` OU `null`** |
| Site público do desenvolvedor | **PREENCHER COM URL HTTPS** |
| URL pública da política | **HOSPEDAR E PREENCHER** |
| URL pública da página de suporte | **HOSPEDAR E PREENCHER** |
| D‑U‑N‑S | **OBRIGATÓRIO SE A CONTA FOR DE ORGANIZAÇÃO** |

O e-mail público de suporte é obrigatório na ficha. `supportPhone` é o telefone
público opcional de suporte do app; ele não substitui o telefone privado da
conta, que precisa ser verificado, nem o telefone público de desenvolvedor que
pode ser exigido para uma organização.

Todas as contas devem manter na Console e-mail e telefone privados verificados
para contato com a Google. Em conta pessoal, confirme também nome/endereço
legais, e-mail público de desenvolvedor, site HTTPS e eventual verificação de
aparelho. Em conta de organização, confirme D‑U‑N‑S, dados legais, site oficial,
telefone/e-mail da organização e telefone/e-mail públicos do desenvolvedor; os
contatos devem corresponder à organização e, sempre que possível, ao domínio do
site. Não coloque contatos privados no JSON, GitHub ou pacote público.

## 3. Criação do aplicativo

Na tela **Criar app**:

1. Idioma padrão: **Português (Brasil)**.
2. Nome: **PalavraX: Aprenda Inglês**.
3. Selecione **Jogo**.
4. Selecione **Gratuito**.
5. Informe o e-mail público real de suporte.
6. Confirme as Políticas do Programa para Desenvolvedores.
7. Confirme as leis de exportação dos Estados Unidos.
8. Aceite os termos do **Play App Signing**.

Um app que já foi disponibilizado gratuitamente não pode depois virar pago com
o mesmo package. O PalavraX não possui compras nem assinaturas.

## 4. Configurações e ficha da loja

- Tipo: **Jogo**.
- Categoria: **Palavras**.
- Idioma principal: **pt-BR**.
- País/região inicial: **Brasil**.
- Nome instalado no Android: **PalavraX**.
- Título da ficha: **PalavraX: Aprenda Inglês**.
- Descrição curta e completa: no pacote, copiar de
  `store/pt-BR/STORE_LISTING_COPY.md`; no repositório, de
  `play_store/pt-BR/listing.json`.
- Notas da versão: no pacote, copiar de
  `store/pt-BR/release-notes-1.0.0.txt`; no repositório, de
  `play_store/pt-BR/release_notes_1.0.0.txt`.
- Ordem e caminho de cada imagem: no pacote, seguir
  `store/pt-BR/ASSET_UPLOAD_MAP.md`.
- Tags: escolher no máximo cinco opções realmente disponíveis na Console. Se
  forem oferecidas, priorizar **Palavras**, **Educativo**, **Quebra-cabeça**,
  **Aprendizado de idiomas** e **Casual**. Não usar tags irrelevantes.
- Marketing externo: decisão do titular; não altera o binário.
- Google Play Games no PC: desativar a distribuição nesta primeira versão se a
  Console oferecer essa opção, pois a release foi validada para celular e
  tablet em retrato, não para PC.

## 5. Conteúdo do app — respostas exatas

### Política de privacidade

- Existe política: **Sim**.
- URL: usar `privacyPolicyUrl` depois de hospedar o HTML gerado.
- A mesma política está acessível dentro do app: **Sim**, em **Sobre,
  privacidade e licenças**.
- A página deve ser HTTPS, pública, sem login, não geobloqueada, legível em
  navegador, não editável pelo público e não pode ser PDF.

### Anúncios

Selecione: **Não, meu app não contém anúncios**.

O binário não possui SDK de anúncios, publicidade própria, anúncios nativos ou
promoções pagas dentro do jogo.

### Acesso ao app / detalhes de login

Selecione: **Todas as funcionalidades estão disponíveis sem acesso especial**.

Texto para o revisor, se houver campo livre:

> O PalavraX funciona totalmente offline e não exige login, conta, assinatura,
> localização ou credenciais. Todas as telas podem ser acessadas diretamente
> após abrir o app.

### Público-alvo e conteúdo

Selecione somente:

- **13–15 anos**;
- **16–17 anos**;
- **18 anos ou mais**.

Não selecione faixas abaixo de 13 anos e não inscreva esta versão no programa
Famílias. O app não foi projetado especificamente para crianças.

### Segurança dos dados (Data Safety)

- O app coleta ou compartilha algum tipo obrigatório de dado do usuário?
  **Não**.
- Dados são transmitidos para fora do aparelho? **Não**.
- Há SDKs que transmitam dados? **Não**.
- Há processamento remoto ou efêmero? **Não**.
- Criptografia em trânsito: **Não se aplica**, pois não há transmissão.
- O usuário pode solicitar exclusão de dados remotos? **Não se aplica**, pois
  não existe servidor nem conta.
- Há criação de conta? **Não**.
- URL de exclusão de conta: **Não se aplica**.

Progresso, tentativas, rascunhos e preferência de som ficam no armazenamento
privado do Android. Armazenamento exclusivamente local não é coleta para esse
formulário. A exclusão ocorre ao limpar os dados do app ou desinstalá-lo.

### Advertising ID

- O app usa o ID de publicidade? **Não**.
- O manifesto declara `com.google.android.gms.permission.AD_ID`? **Não**.

### Recursos financeiros

Selecione: **Meu app não oferece recursos financeiros**.

Não há banco, empréstimo, carteira, pagamento, investimento, criptomoeda,
seguro, compra ou venda de produto financeiro.

### Recursos de saúde

Selecione: **Meu app não oferece recursos de saúde**.

Não há monitoramento físico, mental ou médico, orientação clínica, dados de
saúde, Health Connect ou alegação terapêutica.

### Governo

Selecione: **Não é um app governamental e não comunica serviços ou informações
governamentais**.

### Notícias e revistas

Selecione: **Não é um app de notícias ou revista**.

### COVID-19

Selecione: **Não possui rastreamento de contatos nem funcionalidade de status
de COVID-19**.

### Permissões sensíveis ou de alto risco

**Nenhuma.** O release não solicita Internet, localização, câmera, microfone,
contatos, telefone, SMS, registro de chamadas, armazenamento amplo ou
visibilidade ampla de apps. Não é necessário formulário especial de permissão.

### Outros recursos regulados

- Apostas ou dinheiro real: **Não**.
- Conteúdo gerado por usuários: **Não**.
- Compartilhamento de conteúdo: **Não**.
- Chat ou comunicação entre usuários: **Não**.
- Namoro ou encontro de pessoas: **Não**.
- Compras no app: **Não**.
- Assinaturas: **Não**.
- Contas e exclusão de conta: **Não se aplica**.

## 6. Classificação indicativa IARC

Categoria do questionário: **Jogo**. Informe um e-mail real para receber o
certificado e guarde o certificado da classificação emitida.

O catálogo não possui imagens violentas, sexo, nudez, linguagem ofensiva,
apostas, interação de usuários ou compras. Entretanto, há referências textuais
educativas leves em palavras/definições sobre conflito, morte e bebida
alcoólica. Quando o questionário incluir essas referências, declare-as como
texto leve, sem imagens, incentivo, recompensa ou jogabilidade relacionada.

Não escolha manualmente uma classificação e não presuma “Livre”. Aceite e
confira a classificação calculada pelo IARC.

## 7. Países, preço e dispositivos

- Preço: **Gratuito**.
- País inicial: **Brasil**.
- Celular e tablet Android: **Ativados**.
- Wear OS, Android TV, Automotive, XR e Chromebook/PC não testados: **não
  ativar nesta primeira release**, salvo após validação específica.

Na página **Países/regiões** da track de produção, selecione Brasil. A primeira
release de produção não usa lançamento gradual por percentual; envie somente
quando quiser disponibilizá-la ao público selecionado.

## 8. Assinatura e arquivo de release

- Arquivo para enviar: `app-release.aab`.
- Não enviar o APK como release de produção de um app novo.
- Ativar **Play App Signing**.
- A chave externa do projeto é a **upload key**, não a futura chave de
  distribuição da Play.
- Nunca enviar `lexinexo-upload.jks`, senhas ou `keystore.properties` para o
  GitHub, e-mail, suporte ou pasta pública.
- Guardar backups seguros da JKS e das senhas em pelo menos dois locais
  privados.
- Depois do primeiro upload, baixar e arquivar os certificados públicos da
  upload key e da app signing key gerada pela Google.

O APK incluído no kit serve para instalação direta e QA. O AAB assinado é o
arquivo correto para a Play Console.

## 9. Testes e acesso à produção

Comece pelo **Teste interno**, envie o AAB e confira o App Bundle Explorer e o
relatório de pré-lançamento.

Se a conta for pessoal e tiver sido criada depois de 13/11/2023:

1. Verifique um aparelho Android físico pelo app móvel da Play Console.
2. Crie um teste fechado.
3. Mantenha pelo menos 12 testadores inscritos continuamente por 14 dias.
4. Recolha feedback real.
5. Solicite acesso à produção e responda às perguntas sobre o teste.
6. Aguarde a aprovação do acesso.

Essa exigência específica não se aplica a conta de organização nem a conta
pessoal mais antiga, mas o teste interno continua recomendado.

## 10. Verificação de identidade e package

- Verificar identidade, e-mail e telefone do titular.
- Para organização, verificar o D‑U‑N‑S e a correspondência dos dados legais.
- Confirmar o registro de `com.lexinexo.app` na conta.
- Até 30/09/2026, conferir que o package está registrado para a verificação de
  desenvolvedor Android aplicável ao Brasil.

Antes do lançamento público, pesquise **PalavraX** no INPI e nas lojas
relevantes. A ausência de resultados em busca comum, a disponibilidade do nome,
do package ou de um domínio não equivale a liberação jurídica de marca. Procure
orientação profissional se houver conflito ou dúvida.

## 11. Ordem final de envio

1. Preencher e validar `publication_metadata.json`.
2. Gerar e hospedar as páginas de privacidade e suporte.
3. Criar o app com os dados da seção 1.
4. Preencher contatos, categoria e ficha.
5. Enviar ícone, feature graphic e screenshots.
6. Concluir todas as declarações desta matriz.
7. Preencher e aceitar a classificação IARC.
8. Selecionar Brasil e celular/tablet.
9. Ativar Play App Signing.
10. Enviar o AAB ao teste interno.
11. Resolver todos os erros e avisos relevantes do pré-lançamento.
12. Cumprir teste fechado quando aplicável.
13. Criar a release `1.0.0 (1)` e colar as notas da versão.
14. Enviar para análise e, após aprovação, publicar no Brasil.

## Fontes oficiais

- [Criar e configurar o app](https://support.google.com/googleplay/android-developer/answer/9859152?hl=pt-BR)
- [Preparar o app para análise](https://support.google.com/googleplay/android-developer/answer/9859455?hl=pt-BR)
- [Recursos gráficos da ficha](https://support.google.com/googleplay/android-developer/answer/9866151?hl=pt-BR)
- [Segurança dos dados](https://support.google.com/googleplay/android-developer/answer/10787469?hl=pt-BR)
- [Classificação e público](https://support.google.com/googleplay/android-developer/answer/9859655?hl=pt-BR)
- [Categorias e tags](https://support.google.com/googleplay/android-developer/answer/9859673?hl=pt-BR)
- [Declaração de saúde](https://support.google.com/googleplay/android-developer/answer/14738291?hl=pt-BR)
- [Declaração financeira](https://support.google.com/googleplay/android-developer/answer/13849271?hl=pt-BR)
- [Teste exigido para novas contas pessoais](https://support.google.com/googleplay/android-developer/answer/14151465?hl=pt-BR)
- [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756?hl=pt-BR)
- [Target API](https://developer.android.com/google/play/requirements/target-sdk)
- [Registro do package](https://support.google.com/googleplay/android-developer/answer/16984799?hl=pt-BR)
