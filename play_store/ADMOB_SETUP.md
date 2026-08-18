# Configuração do AdMob — Worde

O código usa `google_mobile_ads` 9.1.0, Google Mobile Ads SDK e UMP. Builds
debug usam exclusivamente os IDs oficiais de teste do Google. Builds release
falham antes da compilação se os dois IDs reais abaixo estiverem ausentes,
inválidos ou forem IDs de teste.

## 1. Criar o app e a unidade

1. Na conta real do AdMob, adicione um app Android chamado **Worde** com package
   **`worde.com`**.
2. Copie o **App ID**, no formato
   `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`.
3. Crie uma unidade **Intersticial** chamada
   `worde-android-between-results` e copie o ID no formato
   `ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY`.
4. Mantenha todos os tipos de anúncio habilitados e use piso de eCPM
   **Google otimizado — todos os preços** no lançamento.
5. Configure também no painel um limite conservador de frequência de
   **1 impressão a cada 3 minutos por usuário**. O app aplica adicionalmente
   seu próprio limite: somente após cada 3 resultados e nunca antes de
   transcorrerem 3 minutos desde a última exibição.

Não crie banner sobre o teclado, App Open ou anúncio ao sair. O código não
implementa esses formatos. O intersticial é pré-carregado, aparece apenas em
pausa natural após o feedback de um resultado e é ignorado se não estiver
pronto; uma falha nunca bloqueia a partida.

## 2. Consentimento e privacidade

Em **Privacidade e mensagens** no AdMob:

1. publique uma mensagem de regulamentações europeias para EEE, Reino Unido e
   Suíça, com português e inglês e a URL HTTPS real da política;
2. publique as mensagens aplicáveis a estados dos Estados Unidos caso o app
   venha a ser distribuído nessas regiões;
3. mantenha habilitada a opção que permite rever escolhas. O Worde mostra
   **Preferências de privacidade de anúncios** na tela Sobre quando o UMP
   informa que esse acesso é obrigatório;
4. não marque o app como direcionado a menores de 13 anos. O público preparado
   na Play Console é 13–15, 16–17 e 18+; não selecione faixas abaixo de 13 nem o
   programa Famílias sem uma revisão completa da configuração e das políticas.

O SDK só é inicializado para solicitar publicidade depois que
`canRequestAds()` autoriza. O limite máximo de conteúdo publicitário é `T`.

## 3. Variáveis do build release

Defina na sessão de PowerShell usada para o build, sem gravar os valores no Git:

```powershell
$env:WORDE_ADMOB_APP_ID='ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY'
$env:WORDE_ADMOB_INTERSTITIAL_ID='ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY'
. .\scripts\lexinexo-env.ps1
flutter build appbundle --release
flutter build apk --release
```

Os IDs não são senhas, mas pertencem à conta real e precisam corresponder ao
app `worde.com`. Nunca teste clicando em anúncio real. Em desenvolvimento, use
o build debug, que já contém os IDs de teste oficiais.

## 4. app-ads.txt e liberação de anúncios

1. Copie `app-ads.template.txt` para `app-ads.txt`.
2. No AdMob, copie o trecho personalizado que contém o Publisher ID real e
   substitua a linha de exemplo.
3. Publique o arquivo na raiz do domínio informado como site do desenvolvedor:
   `https://SEU-DOMINIO/app-ads.txt`.
4. Mantenha esse mesmo domínio na ficha da Google Play.
5. Depois que a ficha estiver pública, solicite a verificação do app e aguarde
   a revisão de prontidão do AdMob. Anúncios podem ficar limitados até essas
   etapas terminarem.

## 5. Declarações obrigatórias na Play Console

- **Contém anúncios:** Sim.
- **Advertising ID:** Sim.
- **Data Safety:** declarar coleta e compartilhamento pelo Google Mobile Ads de
  localização aproximada derivada do IP, interações no app/anúncios,
  diagnósticos e dispositivo ou outros IDs, para publicidade, análise e
  prevenção de fraude/segurança/conformidade.
- **Criptografia em trânsito:** Sim.
- **Conta:** não há criação de conta.

Use a matriz completa em `pt-BR/data_safety.md` e reconfirme a documentação do
SDK antes de cada atualização.

Referências oficiais:

- <https://developers.google.com/admob/flutter/quick-start>
- <https://developers.google.com/admob/flutter/privacy>
- <https://developers.google.com/admob/flutter/interstitial>
- <https://developers.google.com/admob/android/privacy/play-data-disclosure>
- <https://support.google.com/admob/answer/6201350>
- <https://support.google.com/admob/answer/9363762>
