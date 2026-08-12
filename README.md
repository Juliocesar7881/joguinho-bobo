# PalavraX

PalavraX é um jogo Android de palavras em inglês, com interface em português
brasileiro, 1.000 desafios e dois modos independentes: com dicas bilíngues e
sem dicas. Em cada modo, o jogador escolhe livremente palavras de 3 a 8 letras,
com progresso e partida separados por tamanho. O aplicativo funciona
integralmente offline, não exige conta, não exibe anúncios e não coleta nem
compartilha dados.

O jogo usa um teclado QWERTY adaptativo de três linhas. Vitórias têm animação
curta e um som local opcional, que pode ser silenciado sem afetar a resposta
tátil.

## Requisitos fixados

- Flutter 3.44.8 e Dart 3.12.2
- JDK 17
- Android SDK 36, `minSdk 24` e `targetSdk 36`
- namespace `com.lexinexo.app`
- versão `1.0.0+1`

O ambiente oficial mantém Flutter, Android SDK, JDK, Gradle, Pub, AVDs e
temporários no disco `D:`. Em uma nova sessão do PowerShell, carregue-o antes
de qualquer comando:

```powershell
. .\scripts\lexinexo-env.ps1
```

Use `-PersistUser` somente quando quiser persistir essas variáveis no perfil do
usuário.

## Validação e testes

```powershell
flutter pub get
dart run tool\validate_catalog.dart
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter test integration_test\app_test.dart -d emulator-5554
```

O catálogo usa exclusivamente SCOWL/ESDB `rel-2026.02.25`, commit
`7e99edab8e32f9f9ea2b15f249ca8d4d67237410`. Os avisos legais estão em
`THIRD_PARTY_NOTICES.md`.

## Assinatura e build de release

A assinatura de release é externa ao projeto. `scripts/lexinexo-env.ps1`
define `LEXINEXO_KEY_PROPERTIES` para a upload key armazenada em
`D:\LexiNexoRelease\signing`. Nenhuma senha ou chave privada é versionada. Um
build de release falha de forma explícita quando essa variável ou suas
propriedades estão ausentes.

```powershell
flutter build appbundle --release
flutter build apk --release
```

O AAB é o artefato destinado à Google Play. O APK universal é destinado a
instalação direta e QA; depois da adesão ao Play App Signing, a distribuição
paralela compatível com futuras atualizações da Play deve usar um APK assinado
pelo Google.

## Materiais da Google Play

Os textos, gráficos, política, declarações e scripts de captura/validação ficam
em `play_store/`. Para liberar o kit final, copie
`play_store/publication_metadata.template.json` para
`play_store/publication_metadata.json` e preencha o nome público real, e-mail
válido de privacidade e URL HTTPS pública. Valores de exemplo ou campos vazios
são rejeitados deliberadamente:

```powershell
.\play_store\prepare_publication.ps1
.\play_store\validate_publication.ps1
```

Esses dados públicos e o acesso à Play Console pertencem ao titular da conta e
não são inferidos pelo projeto.
