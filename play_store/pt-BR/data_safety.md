# Segurança dos dados — respostas para a Play Console

Estas respostas descrevem a versão 1.0.0 (`com.lexinexo.app`, código 1). Devem ser reconfirmadas na Play Console antes de cada atualização.

## Coleta e compartilhamento

- O app coleta ou compartilha algum dos tipos de dados obrigatórios? **Não.**
- Há bibliotecas ou SDKs que transmitam dados para terceiros? **Não.**
- Os dados são processados apenas de forma efêmera fora do aparelho? **Não há processamento fora do aparelho.**
- Criptografia em trânsito: **não aplicável**, pois o app não transmite dados.
- Solicitação de exclusão: **não aplicável a dados remotos**, pois não existe conta nem servidor.

## Dados locais

O app grava somente o progresso por modo e categoria de tamanho, o último tamanho e nível abertos, as tentativas, os rascunhos e a preferência de som de acerto no armazenamento privado do Android. Esses dados não saem do aparelho. O usuário pode apagá-los em **Configurações → Apps → PalavraX → Armazenamento → Limpar dados** ou ao desinstalar o app.

O som de acerto é reproduzido a partir de um arquivo empacotado. O app não usa o microfone, não grava áudio e não acessa a biblioteca de mídia.

## Declaração resumida

Selecionar na Play Console que o aplicativo **não coleta nem compartilha dados do usuário**. Informar a URL HTTPS produzida a partir dos metadados validados de publicação no campo de política de privacidade.
