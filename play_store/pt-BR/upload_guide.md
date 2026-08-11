# Guia de upload — LexiNexo 1.0.0

## 1. Completar a identidade pública

1. Copie `play_store/publication_metadata.template.json` para `play_store/publication_metadata.json`.
2. Substitua todos os exemplos pelo nome público, e-mail de privacidade e URL HTTPS reais do titular da conta.
3. Execute `play_store/prepare_publication.ps1`. O script gera a política HTML e bloqueia placeholders, contato inválido, URL sem HTTPS, textos fora dos limites e imagens ausentes.
4. Hospede a política gerada exatamente na URL declarada e confirme acesso público sem login.

## 2. Criar o aplicativo

- Nome: **LexiNexo**.
- Idioma padrão: **Português (Brasil)**.
- Aplicativo ou jogo: **Jogo**.
- Gratuito ou pago: **Gratuito**.
- Package: **com.lexinexo.app**. Não altere depois do primeiro upload.
- Ative o Play App Signing e use a chave enviada apenas como upload key.

## 3. Preencher a ficha

- Copie título e descrições de `listing.json`.
- Envie o ícone e a feature graphic de `graphics/`.
- Envie as seis imagens de `screenshots/phone/` (1080×1920) e as quatro imagens de `screenshots/tablet/` (1440×2560) nas categorias correspondentes. Todas são PNG truecolor RGB de 24 bits, sem canal alpha.
- Antes do envio, execute `capture_screenshots.ps1` com a build final. As capturas devem mostrar o seletor de tamanhos, as grades de categoria, as dicas bilíngues, o teclado de três linhas e o feedback de vitória descritos em `screenshot_copy.md`.
- Use `screenshot_copy.md` para conferir os estados exibidos e os textos alternativos.
- Confira tamanhos e hashes em `STORE_ASSETS_SHA256.txt` antes do envio.
- Categoria: **Jogo → Palavras**.
- E-mail de contato e política: use somente os valores validados em `publication_metadata.json`.

## 4. Conteúdo e segurança

- Declare que o app não contém anúncios.
- Informe acesso irrestrito: não há conta nem credenciais.
- Preencha Segurança dos dados conforme `data_safety.md`.
- Preencha público-alvo e IARC conforme `iarc_and_declarations.md`; confira a classificação gerada pelo IARC.
- Use as notas de `release_notes_1.0.0.txt`.

## 5. Release

1. Confirme que a conta e a identidade do desenvolvedor estão verificadas.
2. Execute o gate técnico e confira o relatório de release do projeto.
3. Envie `build/app/outputs/bundle/release/app-release.aab` primeiro ao teste interno.
4. Confira nome, versão 1.0.0 (código 1), aparelhos compatíveis, integridade, permissões e avisos do pré-lançamento.
5. Promova à produção somente após resolver todos os alertas obrigatórios. Se a conta pessoal estiver sujeita ao teste fechado obrigatório, cumpra o período e a quantidade de participantes exibidos pela Play Console antes de solicitar acesso à produção.

## Gate final

O conteúdo estático pode ser conferido antes de receber os dados públicos reais:

```powershell
& .\play_store\validate_static_kit.ps1
```

Essa verificação cobre textos, nomes, limites e dimensões dos materiais. Ela não substitui a recaptura após mudanças visuais. O gate completo abaixo permanece fechado até existirem `publication_metadata.json` com dados reais e a política HTML final correspondente.

```powershell
& .\play_store\prepare_publication.ps1
```

Saída esperada: `Kit de publicacao LexiNexo 1.0.0 validado.` Qualquer falha interrompe a liberação.
