# Worde 1.0.0 — relatório de release

Última atualização deste relatório: 17 de agosto de 2026
(America/Sao_Paulo)

## Estado

O release com anúncios **ainda não está aprovado para upload**. O código passou
a usar Google Mobile Ads/UMP, e o teclado foi elevado novamente; por isso, os
AAB/APK e hashes gerados em 14 de agosto pertencem à revisão anterior sem esse
SDK e não são candidatos da versão atual.

O build de produção falha fechado até o titular fornecer um App ID e uma unidade
intersticial reais do AdMob. Também faltam o Publisher ID para `app-ads.txt`, o
tipo e a identidade verificados da conta, nome público do desenvolvedor,
contatos reais de suporte e privacidade, site HTTPS, páginas HTTPS públicas de
suporte e privacidade e acesso à Play Console. Nenhum desses valores foi
inventado.

Depois de receber esses dados, é obrigatório reconstruir e revalidar o AAB/APK
de produção e substituir os campos pendentes deste relatório. As dez capturas
atuais e o inventário gráfico já foram regenerados e validados. Um APK debug
com IDs oficiais de teste foi gerado para QA, mas não é publicável nem
monetizável.

## Artefatos anteriores — obsoletos

| Artefato | Tamanho | SHA-256 |
|---|---:|---|
| AAB pré-AdMob (`build/app/outputs/bundle/release/app-release.aab`) | 51.124.746 bytes | `21763747DF275A1898CD6645108253FCA3B174E9023E2A2C4A089891AEAC8049` |
| APK pré-AdMob (`build/app/outputs/flutter-apk/app-release.apk`) | 51.248.273 bytes | `7B315088C3CAF5E37BC5B1FF8AE4D3EC23E778AEBF0535DD65E74DE09C39A218` |

Esses dois arquivos não contêm a implementação atual de anúncios e não devem ser
enviados. `play_store/RELEASE_ARTIFACTS.json`, o pacote em `dist/` e os hashes
dos binários também precisam ser regenerados após o build final.

## APK atual para QA — anúncios oficiais de teste

| Artefato | Tamanho | SHA-256 |
|---|---:|---|
| `build/app/outputs/flutter-apk/Worde-1.0.0-test-ads.apk` | 181.506.305 bytes | `3A3BF648F492B7804662E22A31011FE0C0014110F958FD7AF79D4EF921229B36` |

Esse APK universal contém `armeabi-v7a`, `arm64-v8a` e `x86_64`, usa somente os
IDs oficiais de teste do Google, possui um signatário debug e serve para
instalação/avaliação funcional. Ele foi instalado e iniciado com sucesso no AVD
Android 36 de páginas de 16 KiB, com Wi-Fi e dados móveis desligados. Não o
envie à Play Console. A verificação `zipalign -c -P 16 4` também passou.

## Identidade Android

- Package e namespace: `worde.com`
- Nome instalado: `Worde`
- Título da ficha: `Worde: Aprenda Palavras`
- `versionName`: `1.0.0`
- `versionCode`: `1`
- `minSdk`: 24
- `targetSdk`: 36
- `compileSdk`: 36
- ABIs: `armeabi-v7a`, `arm64-v8a` e `x86_64`
- Orientação da `MainActivity`: retrato
- `android:allowBackup`: `false`
- Release sem `debuggable` e sem `testOnly`
- Permissões perigosas em runtime: nenhuma
- Permissões do APK QA atual: `INTERNET`, `ACCESS_NETWORK_STATE`, `AD_ID`,
  `ACCESS_ADSERVICES_AD_ID`, `ACCESS_ADSERVICES_ATTRIBUTION`,
  `ACCESS_ADSERVICES_TOPICS`, `WAKE_LOCK`, `FOREGROUND_SERVICE` e a permissão
  interna `worde.com.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`

## Assinatura de upload

- Keystore privado: externo ao projeto e deliberadamente ausente do pacote
- Certificado público no pacote: `signing-public/upload-certificate.pem`
- Alias: `lexinexo-upload`
- Chave: RSA 4096 bits, `SHA256withRSA`
- SHA-1: `52:34:B6:6F:FD:24:13:F6:F5:6C:C3:5C:24:3F:F1:42:2C:A5:A2:33`
- SHA-256: `59:54:66:16:88:06:3D:35:EF:33:92:B7:50:2F:46:22:D1:ED:6F:0A:74:FD:63:8E:46:68:88:CB:C4:78:79:96`
- SHA-256 do JKS: `5DF4A05795E0193D957321A9FC19BE1909DB0AAF372C17BB34C12157CEDBD6BB`
- SHA-256 do PEM: `9301F00325D897E505D7C835BA2EEBDEB2308A8802F57A7841706B1986F24E42`

A chave privada e as senhas permanecem fora do projeto, com ACL limitada ao
usuário local. Tarefas Gradle release falham se
`LEXINEXO_KEY_PROPERTIES` não estiver configurado. O APK possui exatamente um
signatário; no release anterior, o certificado coincidiu com a upload key e o
AAB passou na validação de assinatura JAR. Isso será verificado novamente no
release com IDs AdMob reais.

## Recursos entregues nesta revisão

- fluxo início → modo → categoria de 3, 4, 5, 6, 7 ou 8 letras → grade → jogo;
- progresso, rascunho, sessão e resultado terminal independentes por modo e
  tamanho, preservando migração do save v1 para o schema v2 na chave existente;
- numeração local por categoria, mantendo os IDs canônicos 1–500;
- seletor de tamanho redesenhado como uma grade compacta 3×2, com progresso e
  estado de sessão em cards menores;
- teclado QWERTY adaptativo fixo em três linhas, com altura de 44–48 dp e
  largura limitada em tablets, agora elevado 44 dp da borda inferior;
- separação de 18 dp entre o tabuleiro e o teclado, sem empurrar as teclas para
  fora da tela;
- área superior rolável e teclado sempre acessível em telas baixas e texto 2×;
- dica em português e `Hint (EN)` somente no modo com dicas;
- preferência de som salva localmente, efeito original via SoundPool sem nova
  permissão e animação de check antes do diálogo de vitória;
- Google Mobile Ads/UMP com intersticial somente em pausa natural, uma
  oportunidade a cada três resultados novos e intervalo local mínimo de três
  minutos; ausência/falha de anúncio não bloqueia o jogo e resultados
  restaurados não disparam publicidade;
- opção de rever preferências de privacidade na tela Sobre quando exigida pela
  UMP, classificação máxima de conteúdo publicitário `T` e IDs de teste
  restritos ao debug;
- nova identidade Worde baseada no ícone fornecido pelo titular, com os cinco
  blocos `worde`, lupa de aprendizado, fundo azul e camada monocromática para
  launchers compatíveis;
- recuperação segura de falha de persistência e serialização de gravações
  concorrentes, sem ressuscitar uma mutação que falhou.

O WAV original possui 45.908 bytes e SHA-256
`7D978AD5794C6620556F82C29F4C2695784E2CFD96FE1A7065360D433BA3BD70`.

## Catálogo e revisão editorial

- Fonte exclusiva: SCOWL/ESDB `rel-2026.02.25`
- Commit: `7e99edab8e32f9f9ea2b15f249ca8d4d67237410`
- Expansão: `en_US`, `en_GB-ise` e `en_GB-ize` com
  `hunspell-reader 10.0.1`
- Tentativas aceitas: 42.039, únicas, ordenadas e divididas por comprimento
- Níveis: 500 com dicas e 500 sem dicas, com 1.000 respostas únicas
- Dicas inglesas: 500, presentes apenas no modo com dicas
- Revisão editorial v2: 1.000 registros com duas passagens automatizadas
  identificadas, datas, hashes canônicos e aprovações separadas; nenhuma revisão
  humana é alegada pelo manifesto
- Dados: 836.590 bytes brutos e 234.412 bytes comprimidos
- SHA-256 de `data_manifest.json`:
  `66AA0CDDD1A315913FE678F66A5669546DF7011A881DDBD3F2A225F3329997BD`
- SHA-256 de `editorial_review.json`:
  `B2A46A5466B842AE6042BA5FAEB914056E9574C3B81FD739E1E8E1C938F6043B`

O validador compartilhado aprovou quantidades, numeração, faixas, campos,
duplicidades, denylist, dicas PT/EN, textos truncados, famílias de templates,
hashes, versões, dicionários e aprovações editoriais. Os avisos legais do SCOWL
e do `hunspell-reader` estão em `THIRD_PARTY_NOTICES.md` e dentro do app.

## Validação da revisão atual com AdMob

Executado em 17 de agosto de 2026:

1. `flutter pub get`: aprovado.
2. Validador Dart e verificador Node do catálogo: 1.000 níveis, 42.039
   tentativas e limites de dados aprovados.
3. `dart format --output=none --set-exit-if-changed .`: 50 arquivos, nenhuma
   alteração.
4. `flutter analyze --fatal-infos`: nenhum problema.
5. `flutter test`: 152 testes aprovados.
6. `integration_test/app_test.dart` no AVD Android 36 normal, offline: 3/3.
7. Captura integrada real: seis screenshots phone e quatro tablet; todas
   inspecionadas visualmente e validadas por dimensão, formato e SHA-256.
8. AVD Android 36 de 16 KiB: `PAGE_SIZE=16384`; APK QA instalado, atividade
   principal retomada e nenhum crash/ANR do Worde.
9. Tooling e kit estático da Play Store: aprovados.
10. Build release sem IDs reais: rejeitado corretamente com a mensagem
    `Release AdMob App ID is missing or invalid`.
11. Gate completo de publicação: rejeitado corretamente apenas porque
    `play_store/publication_metadata.json` real ainda não foi fornecido.

Os testes cobrem frequência de três resultados/intervalo de três minutos,
consentimento, falha de anúncio sem bloquear o jogo, vitória e derrota frescas,
ausência de anúncio em resultado restaurado, som/animação, persistência,
migração, categorias e layouts responsivos. O SDK também descarta anúncios
vencidos após uma hora, invalida o cache ao rever consentimento, evita
reentrância do formulário e tenta novo preload ao retomar o app.

## Baseline anterior

Antes da inclusão do SDK de anúncios, a sequência abaixo havia sido concluída:

1. `flutter pub get`: aprovado.
2. `dart run tool\validate_catalog.dart`: 1.000 níveis, 42.039 tentativas e
   limites de dados aprovados.
3. `dart format --output=none --set-exit-if-changed .`: 47 arquivos, nenhuma
   alteração.
4. `flutter analyze --fatal-infos`: nenhum problema.
5. `flutter test`: 148 testes aprovados.
6. `integration_test/app_test.dart` no AVD Android 36 normal, offline: 3/3.
7. Captura integrada real: 6 screenshots phone e 4 tablet, ambos os roteiros
   aprovados; imagens inspecionadas visualmente.
8. `integration_test/app_test.dart` no AVD Android 36 de 16 KiB, offline: 3/3.
9. Busca por `TODO`, `FIXME` e `Lorem`: nenhuma pendência no produto; somente as
   denylist dos próprios validadores contêm esses termos.
10. Build AAB e APK release assinado: aprovado para a revisão anterior.
11. Verificação integral dos artefatos e cold start do APK release: aprovado
    para a revisão anterior.

Esse histórico não substitui o build final. Depois de receber os IDs reais, o
AAB/APK de produção deve ser construído e ter assinatura, IDs, manifesto,
permissões, alinhamento 16 KiB e instalação novamente verificados.

A suíte cobre avaliação com letras repetidas, teclado, palavra incompleta ou
inválida sem consumo, sexta tentativa, desbloqueio por categoria, replay, modos
e tamanhos independentes, nível 500, migração v1, corrupção isolada, versão
incompatível, vitórias/derrotas restauradas, falhas concorrentes de escrita,
diálogos recuperáveis, dica por modo, 320×568, 412×915, tablet, oito letras,
texto 2×, som ligado/desligado, falha de áudio e animações reduzidas.

## Validação Android e 16 KiB

O verificador da revisão anterior aprovou:

- `bundletool validate`, `jarsigner`, `keytool`, `apksigner`, `aapt` e
  `zipalign -c -P 16 -v 4`;
- package, versão, SDKs, backup, retrato, modo debug/test e permissões;
- signatário único e certificado de upload exato;
- `PAGE_ALIGNMENT_16K` no AAB;
- todos os ELF detectados por assinatura binária, inclusive fora de extensões
  convencionais;
- ABI compatível com `Machine` e nenhum diretório ABI extra;
- todos os segmentos `LOAD` alinhados a pelo menos 16.384 bytes.

Foram verificados 9 ELF no APK e 15 no AAB anterior. No AVD especial, `getconf PAGE_SIZE`
retornou `16384`, Wi-Fi estava desativado e `mobile_data=0`. O APK release foi
instalado e iniciou a `MainActivity` a frio com status `ok`; a atividade ficou
retomada, renderizou a tela inicial e permaneceu ativa sem crash.

Na revisão atual, o APK QA com Google Mobile Ads foi instalado no mesmo tipo de
AVD; `getconf PAGE_SIZE` retornou `16384`, o processo permaneceu ativo e
`worde.com/.MainActivity` ficou como `topResumedActivity`, sem crash ou ANR.

## Ambiente fixado no disco D:

- Flutter 3.44.8 stable, framework `058e0af2c2`
- Dart 3.12.2
- JDK 17
- Android SDK e Build Tools 36.0.0
- NDK 28.2.13676358
- Android Gradle Plugin 9.0.1
- Gradle 9.1.0
- Kotlin 2.3.20
- bundletool 1.18.3
- `shared_preferences 2.5.5`
- `google_mobile_ads 9.1.0`

Flutter, Android SDK, JDK, Gradle, Pub, temporários e AVDs usam o D:. A entrada
oficial do ambiente é:

```powershell
. .\scripts\lexinexo-env.ps1
```

## Kit Google Play

Diretório: `play_store/pt-BR`

- título, descrição curta e descrição completa em PT-BR;
- notas da versão, textos alternativos e guia de upload;
- ícone 512×512 PNG RGBA;
- feature graphic 1024×500 JPEG RGB24;
- 6 screenshots phone 1080×1920 PNG RGB24;
- 4 screenshots tablet 1440×2560 PNG RGB24;
- política de privacidade em templates HTML e Markdown, com gerador que injeta
  somente metadados reais;
- matriz Data Safety, IARC, declaração de anúncios, Advertising ID e UMP;
- guia de configuração do AdMob e template de `app-ads.txt`;
- inventário SHA-256 dos 12 materiais gráficos.

O inventário gráfico atual foi regenerado e seus 12 registros foram verificados.
SHA-256 de `STORE_ASSETS_SHA256.txt`:
`3A1F5FA3C8322D0A6E590B3669F8AE15DBCC1A1DB9FA69F21D620A3157ABA22A`.

O kit narrativo, os gráficos/capturas e os validadores estáticos estão atuais.
O gate completo permanece bloqueado por `play_store/publication_metadata.json`,
pelos IDs reais do AdMob, pelo Publisher ID e pelos novos artefatos release
assinados.

## Etapas externas restantes

Os caminhos e comandos a seguir são relativos ao repositório-fonte; os
artefatos equivalentes do pacote estão identificados nas seções anteriores.

1. Criar o app `worde.com` e a unidade intersticial na conta real do AdMob;
   fornecer `WORDE_ADMOB_APP_ID`, `WORDE_ADMOB_INTERSTITIAL_ID` e o Publisher ID
   real, publicar as mensagens UMP e o `app-ads.txt` conforme
   `play_store/ADMOB_SETUP.md`.
2. Copiar `play_store/publication_metadata.template.json` para
   `play_store/publication_metadata.json` e preencher todos os campos reais do
   schema v2: tipo de conta, nome público, contatos, site e URLs HTTPS de suporte
   e privacidade.
3. Executar `play_store/prepare_publication.ps1`; ele gera as políticas finais
   HTML e Markdown. Hospedar o HTML exatamente na URL declarada e rodar
   `play_store/validate_publication.ps1`.
4. Reconstruir AAB/APK release, executar toda a suíte, validar assinatura,
   permissões, 16 KiB e instalação, confirmar o kit gráfico atual e atualizar
   os hashes dos binários.
5. Na Play Console: verificar identidade e contatos privados da conta; para
   organização, confirmar D‑U‑N‑S e contatos públicos exigidos; reservar
   `worde.com`, aderir ao Play App Signing, preencher Data
   Safety/IARC/público, declarar que contém anúncios e enviar primeiro ao teste
   interno.
6. Se a conta real for pessoal criada depois de 13/11/2023, cumprir o teste
   fechado exigido antes da produção.
7. Antes do lançamento público, pesquisar **Worde** no INPI e avaliar
   eventuais conflitos de marca; disponibilidade do nome/package não é parecer
   jurídico.

## Instalação direta do APK

Para avaliar agora, use `Worde-1.0.0-test-ads.apk`; ele exibe anúncios de teste e
não deve ser enviado à loja. Para distribuição pública, aguarde o APK/AAB release
reconstruído com os IDs reais. O APK pré-AdMob listado acima está obsoleto.

1. Copie `Worde-1.0.0-test-ads.apk` para o telefone Android.
2. Ao abrir o arquivo, permita temporariamente **Instalar apps desconhecidos**
   para o app usado na abertura (por exemplo, Arquivos ou navegador).
3. Confirme a instalação e abra **Worde**.
4. Se desejar, desative novamente essa autorização depois da instalação.
