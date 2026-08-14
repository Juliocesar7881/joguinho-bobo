# Guia de upload — Worde 1.0.0

## 1. Completar a identidade pública

1. No pacote extraído, leia `owner-action/PREENCHA_COM_SEUS_DADOS.md` e preencha `owner-action/publication_metadata.json` a partir do template. No repositório-fonte, os arquivos equivalentes ficam em `play_store/`.
2. Substitua todos os exemplos do schema v2 pelo tipo de conta, nome público, e-mails, site, página de suporte e URL da política reais do titular.
3. No repositório-fonte, execute `play_store/prepare_publication.ps1`. O script gera as páginas finais em `play_store/generated_publication/` e bloqueia placeholders, contato inválido, URL sem HTTPS, textos fora dos limites e imagens ausentes. Se estiver somente com o pacote, siga as instruções de preenchimento dos templates em `owner-action/PREENCHA_COM_SEUS_DADOS.md`.
4. Hospede `privacy_policy.html` e `support_page.html` exatamente nas URLs declaradas e confirme acesso público sem login.

## 2. Criar o aplicativo

- Nome: **Worde: Aprenda Palavras**.
- Idioma padrão: **Português (Brasil)**.
- Aplicativo ou jogo: **Jogo**.
- Gratuito ou pago: **Gratuito**.
- Package: **worde.com**. Não altere depois do primeiro upload.
- Ative o Play App Signing e use a chave enviada apenas como upload key.

## 3. Preencher a ficha

- Copie título e descrições de `store/pt-BR/listing.json` ou `store/pt-BR/STORE_LISTING_COPY.md` no pacote; no repositório-fonte, use `play_store/pt-BR/`.
- Envie o ícone e a feature graphic de `store/pt-BR/graphics/`.
- Envie as seis imagens de `store/pt-BR/screenshots/phone/` (1080×1920) e as quatro imagens de `store/pt-BR/screenshots/tablet/` (1440×2560) na ordem definida em `store/pt-BR/ASSET_UPLOAD_MAP.md`. Reutilize o conjunto de tablet nos campos de 7 e 10 polegadas. Todas são PNG truecolor RGB de 24 bits, sem canal alpha.
- As capturas entregues já correspondem à build final. Se o visual do app mudar, recapture-as pelo script `play_store/pt-BR/capture_screenshots.ps1` do repositório-fonte antes do envio.
- Use `store/pt-BR/screenshot_copy.md` para conferir os estados exibidos e os textos alternativos.
- Use `compliance/PLAY_CONSOLE_ANSWERS.md` como matriz campo a campo para todos os formulários e declarações.
- Confira tamanhos e hashes em `store/pt-BR/STORE_ASSETS_SHA256.txt` antes do envio.
- Categoria: **Jogo → Palavras**.
- E-mail de contato e política: use somente os valores reais de `owner-action/publication_metadata.json`.

## 4. Conteúdo e segurança

- Declare que o app não contém anúncios.
- Informe acesso irrestrito: não há conta nem credenciais.
- Preencha Segurança dos dados conforme `compliance/data_safety.md`.
- Preencha anúncios, acesso ao app, público, dados, saúde, finanças, governo, notícias, COVID-19 e IARC conforme `compliance/PLAY_CONSOLE_ANSWERS.md`; confira a classificação gerada pelo IARC.
- Use as notas de `store/pt-BR/release-notes-1.0.0.txt`.

## 5. Release

1. Confirme que a conta e a identidade do desenvolvedor estão verificadas.
2. Execute o gate técnico e confira o relatório de release do projeto.
3. Envie `release/app-release.aab` do pacote primeiro ao teste interno. No repositório-fonte, o mesmo artefato fica em `build/app/outputs/bundle/release/app-release.aab`.
4. Confira nome, versão 1.0.0 (código 1), aparelhos compatíveis, integridade, permissões e avisos do pré-lançamento.
5. Promova à produção somente após resolver todos os alertas obrigatórios. Se a conta pessoal estiver sujeita ao teste fechado obrigatório, cumpra o período e a quantidade de participantes exibidos pela Play Console antes de solicitar acesso à produção.

## Gate final

Os comandos abaixo são executados na raiz do **repositório-fonte**. Eles não são
necessários para usar o pacote já extraído.

O conteúdo estático pode ser conferido antes de receber os dados públicos reais:

```powershell
& .\play_store\validate_static_kit.ps1
```

Essa verificação cobre textos, nomes, limites e dimensões dos materiais. Ela não substitui a recaptura após mudanças visuais. O gate completo abaixo permanece fechado até existirem `publication_metadata.json` com dados reais e a política HTML final correspondente.

```powershell
& .\play_store\prepare_publication.ps1
```

Saída esperada: `Kit de publicacao Worde 1.0.0 validado.` Qualquer falha interrompe a liberação.

Depois do gate, gere a entrega única:

```powershell
& .\play_store\build_submission_package.ps1 -IncludeFinalHostedPages
```

O script cria `dist/Worde-1.0.0-google-play/` e o ZIP correspondente, sem JKS ou senhas.
