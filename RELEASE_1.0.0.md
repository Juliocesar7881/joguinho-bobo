# PalavraX 1.0.0 — relatório de release

Data da validação: 12 de agosto de 2026 (America/Sao_Paulo)

## Estado

O release está tecnicamente aprovado. O AAB e o APK universal foram
reconstruídos com o código atual, assinados pela upload key de produção,
validados e executados offline no Android 36. O APK release também foi instalado
e iniciado em um AVD com páginas de memória de 16 KiB.

O envio completo da ficha à Google Play continua bloqueado somente pelos dados
externos que pertencem ao titular da conta: nome público do desenvolvedor,
e-mail real de privacidade, URL HTTPS pública da política e acesso à Play
Console. Esses valores não foram inventados. O gate completo falha fechado com:

`publication_metadata.json nao existe; os dados publicos reais sao obrigatorios para liberar a publicacao.`

## Artefatos finais

| Artefato | Tamanho | SHA-256 |
|---|---:|---|
| `build/app/outputs/bundle/release/app-release.aab` | 48.032.096 bytes | `B4DF6CB955CEEF6932EE0DADD00567B9111FEDC2EFA37B3E816041B4CF05D3F2` |
| `build/app/outputs/flutter-apk/app-release.apk` | 48.164.396 bytes | `38762729CFA5FAB7CFF68BA72D14ECD8672BBADCDCDFC263558C74216FFCC03E` |

O AAB é o arquivo para upload na Play Console. O APK é universal, assinado pela
upload key, e serve para instalação direta e QA. Depois da adesão ao Play App
Signing, um APK distribuído em paralelo que precise receber as mesmas
atualizações da Play deve usar a assinatura de distribuição do Google.

## Identidade Android

- Package e namespace: `com.lexinexo.app`
- Nome instalado: `PalavraX`
- Título da ficha: `PalavraX: Aprenda Inglês`
- `versionName`: `1.0.0`
- `versionCode`: `1`
- `minSdk`: 24
- `targetSdk`: 36
- `compileSdk`: 36
- ABIs: `armeabi-v7a`, `arm64-v8a` e `x86_64`
- Orientação da `MainActivity`: retrato
- `android:allowBackup`: `false`
- Release sem `debuggable` e sem `testOnly`
- Nenhuma permissão de internet ou permissão perigosa

A única permissão declarada no artefato é a permissão interna AndroidX de nível
`signature`:

`com.lexinexo.app.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`

## Assinatura de upload

- Keystore externo: `D:\LexiNexoRelease\signing\lexinexo-upload.jks`
- Certificado público: `D:\LexiNexoRelease\signing\lexinexo-upload-certificate.pem`
- Alias: `lexinexo-upload`
- Chave: RSA 4096 bits, `SHA256withRSA`
- SHA-1: `52:34:B6:6F:FD:24:13:F6:F5:6C:C3:5C:24:3F:F1:42:2C:A5:A2:33`
- SHA-256: `59:54:66:16:88:06:3D:35:EF:33:92:B7:50:2F:46:22:D1:ED:6F:0A:74:FD:63:8E:46:68:88:CB:C4:78:79:96`
- SHA-256 do JKS: `5DF4A05795E0193D957321A9FC19BE1909DB0AAF372C17BB34C12157CEDBD6BB`
- SHA-256 do PEM: `9301F00325D897E505D7C835BA2EEBDEB2308A8802F57A7841706B1986F24E42`

A chave privada e as senhas permanecem fora do projeto, com ACL limitada ao
usuário local. Tarefas Gradle release falham se
`LEXINEXO_KEY_PROPERTIES` não estiver configurado. O APK possui exatamente um
signatário; o certificado coincide com a upload key. O AAB passou na validação
de assinatura JAR.

## Recursos entregues nesta revisão

- fluxo início → modo → categoria de 3, 4, 5, 6, 7 ou 8 letras → grade → jogo;
- progresso, rascunho, sessão e resultado terminal independentes por modo e
  tamanho, preservando migração do save v1 para o schema v2 na chave existente;
- numeração local por categoria, mantendo os IDs canônicos 1–500;
- seletor de tamanho redesenhado como uma grade compacta 3×2, com progresso e
  estado de sessão em cards menores;
- teclado QWERTY adaptativo fixo em três linhas, com altura de 44–48 dp e
  largura limitada em tablets, elevado 18 dp da borda inferior;
- separação de 18 dp entre o tabuleiro e o teclado, sem empurrar as teclas para
  fora da tela;
- área superior rolável e teclado sempre acessível em telas baixas e texto 2×;
- dica em português e `Hint (EN)` somente no modo com dicas;
- preferência de som salva localmente, efeito original via SoundPool sem nova
  permissão e animação de check antes do diálogo de vitória;
- nova identidade PalavraX, com cinco blocos formando um X, bloco central verde
  com a letra A e camada monocromática para launchers compatíveis;
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
- Dados: 836.590 bytes brutos e 234.410 bytes comprimidos
- SHA-256 de `data_manifest.json`:
  `92AD5C71B466AB8DCCA562A8B1816BF5E962CB625EEFA64C8751FBCD4B5BB151`
- SHA-256 de `editorial_review.json`:
  `B2A46A5466B842AE6042BA5FAEB914056E9574C3B81FD739E1E8E1C938F6043B`

O validador compartilhado aprovou quantidades, numeração, faixas, campos,
duplicidades, denylist, dicas PT/EN, textos truncados, famílias de templates,
hashes, versões, dicionários e aprovações editoriais. Os avisos legais do SCOWL
e do `hunspell-reader` estão em `THIRD_PARTY_NOTICES.md` e dentro do app.

## Testes e verificações executados

Sequência final:

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
10. Build AAB e APK release assinado: aprovado.
11. Verificação integral dos artefatos e cold start do APK release: aprovado.

A suíte cobre avaliação com letras repetidas, teclado, palavra incompleta ou
inválida sem consumo, sexta tentativa, desbloqueio por categoria, replay, modos
e tamanhos independentes, nível 500, migração v1, corrupção isolada, versão
incompatível, vitórias/derrotas restauradas, falhas concorrentes de escrita,
diálogos recuperáveis, dica por modo, 320×568, 412×915, tablet, oito letras,
texto 2×, som ligado/desligado, falha de áudio e animações reduzidas.

## Validação Android e 16 KiB

O verificador final aprovou:

- `bundletool validate`, `jarsigner`, `keytool`, `apksigner`, `aapt` e
  `zipalign -c -P 16 -v 4`;
- package, versão, SDKs, backup, retrato, modo debug/test e permissões;
- signatário único e certificado de upload exato;
- `PAGE_ALIGNMENT_16K` no AAB;
- todos os ELF detectados por assinatura binária, inclusive fora de extensões
  convencionais;
- ABI compatível com `Machine` e nenhum diretório ABI extra;
- todos os segmentos `LOAD` alinhados a pelo menos 16.384 bytes.

Foram verificados 9 ELF no APK e 15 no AAB. No AVD especial, `getconf PAGE_SIZE`
retornou `16384`, Wi-Fi estava desativado e `mobile_data=0`. O APK release foi
instalado e iniciou a `MainActivity` a frio com status `ok`; a atividade ficou
retomada, renderizou a tela inicial e permaneceu ativa sem crash.

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
- matriz Data Safety, IARC e declarações de público/ausência de anúncios;
- inventário SHA-256 dos 12 materiais gráficos.

SHA-256 de `STORE_ASSETS_SHA256.txt`:
`BDC50647B95B4D54D4D609FFED47E1620F896F6BE67A8E326AC435B8A03833D9`.

`play_store/validate_static_kit.ps1` passou. O gate completo permanece bloqueado
somente pela ausência deliberada de `play_store/publication_metadata.json`.

## Etapas externas restantes

1. Copiar `play_store/publication_metadata.template.json` para
   `play_store/publication_metadata.json` e preencher nome público real, e-mail
   real de privacidade e URL HTTPS pública.
2. Executar `play_store/prepare_publication.ps1`; ele gera as políticas finais
   HTML e Markdown. Hospedar o HTML exatamente na URL declarada e rodar
   `play_store/validate_publication.ps1`.
3. Na Play Console: verificar identidade, reservar `com.lexinexo.app`, aderir ao
   Play App Signing, cadastrar contatos, preencher Data Safety/IARC/público e
   ausência de anúncios, e enviar primeiro ao teste interno.
4. Se a conta real for pessoal criada depois de 13/11/2023, cumprir o teste
   fechado exigido antes da produção.

## Instalação direta do APK

1. Copie `app-release.apk` para o telefone Android.
2. Ao abrir o arquivo, permita temporariamente **Instalar apps desconhecidos**
   para o app usado na abertura (por exemplo, Arquivos ou navegador).
3. Confirme a instalação e abra **PalavraX**.
4. Se desejar, desative novamente essa autorização depois da instalação.
