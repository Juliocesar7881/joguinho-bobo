# Segurança dos dados — respostas para a Play Console

Estas respostas descrevem a versão 1.0.0 (`worde.com`, código 1). Devem ser reconfirmadas na Play Console antes de cada atualização.

## Coleta e compartilhamento

- O app coleta algum dos tipos de dados obrigatórios? **Sim, por meio do Google Mobile Ads SDK.**
- O app compartilha dados com terceiros? **Sim, com o Google para publicidade, análise e prevenção de fraude.**
- Há bibliotecas ou SDKs que transmitam dados? **Sim: `google_mobile_ads` 9.1.0, Google Mobile Ads SDK e UMP.**
- Criptografia em trânsito: **Sim, TLS.**
- O usuário pode solicitar exclusão de uma conta? **Não aplicável**, pois o Worde não oferece conta.

## Tipos para declarar

Conferir na versão atual do formulário da Play Console e declarar, no mínimo:

| Categoria da Play | Dado | Coletado | Compartilhado | Finalidades |
|---|---|---:|---:|---|
| Localização | Localização aproximada derivada do endereço IP | Sim | Sim | Publicidade/marketing, análise, prevenção de fraude/segurança/conformidade |
| Atividade no app | Interações com o app e anúncios, incluindo inicialização, toques e visualizações de vídeo | Sim | Sim | Publicidade/marketing, análise, prevenção de fraude/segurança/conformidade |
| Informações e desempenho do app | Diagnósticos, como tempo de inicialização, travamentos e uso de energia | Sim | Sim | Análise, prevenção de fraude/segurança/conformidade |
| Dispositivo ou outros IDs | Identificador de publicidade, App Set ID e identificadores aplicáveis | Sim | Sim | Publicidade/marketing, análise, prevenção de fraude/segurança/conformidade |

O tratamento pode depender do consentimento, da região, das configurações do aparelho e da disponibilidade de anúncios. Mesmo assim, a ficha deve declarar as capacidades do SDK presentes no binário. O desenvolvedor deve reconferir a página oficial de divulgação do Google Mobile Ads antes de cada release.

## Dados locais

O app grava somente o progresso por modo e categoria de tamanho, o último tamanho e nível abertos, as tentativas, os rascunhos e a preferência de som de acerto no armazenamento privado do Android. O Worde não envia esses dados de jogo ao desenvolvedor nem ao SDK de anúncios. O usuário pode apagá-los em **Configurações → Apps → Worde → Armazenamento → Limpar dados** ou ao desinstalar o app.

O som de acerto é reproduzido a partir de um arquivo empacotado. O app não usa o microfone, não grava áudio e não acessa a biblioteca de mídia.

## Declaração resumida

Selecionar na Play Console que o aplicativo **coleta e compartilha dados do usuário por meio do Google Mobile Ads SDK**, que os dados são criptografados em trânsito e que não há criação de conta. Informar a URL HTTPS produzida a partir dos metadados validados no campo de política de privacidade.

Referência oficial para esta matriz: <https://developers.google.com/admob/android/privacy/play-data-disclosure>.
