# Worde 1.0.0 — pacote para Google Play

Esta pasta reúne tudo o que pode ser preparado tecnicamente antes de acessar a
conta do titular na Google Play Console.

## Comece por aqui

1. Leia `compliance/PLAY_CONSOLE_ANSWERS.md`.
2. Confira `identity/APP_IDENTITY.json`.
3. Preencha os dados verdadeiros indicados em
   `owner-action/PREENCHA_COM_SEUS_DADOS.md`.
4. Use `release/app-release.aab` no teste interno da Play Console.
5. Siga `store/pt-BR/upload_guide.md` e `store/pt-BR/ASSET_UPLOAD_MAP.md`.
6. Copie os textos diretamente de `store/pt-BR/STORE_LISTING_COPY.md`.

Todos os caminhos deste documento são relativos à raiz da pasta extraída. As
automações de geração e validação ficam no repositório-fonte; este pacote é a
entrega autocontida para preencher a Console e enviar os materiais.

## Conteúdo

- `release/`: AAB para a Google Play.
- `qa/`: APK universal para instalação direta e testes.
- `signing-public/`: certificado e fingerprints públicos da upload key.
- `store/pt-BR/`: título, descrições, notas, ícone, feature graphic e capturas.
- `mobile-branding/`: imagem original fornecida, master do ícone instalado,
  adaptive foreground, monochrome, splash e renderizador determinístico.
- `compliance/`: respostas para todos os formulários de Conteúdo do app.
- `legal/`: política, suporte, licenças e templates para hospedagem.
- `reports/`: relatório técnico completo da release.
- `owner-action/`: ações que somente o titular da conta pode concluir.
- `SHA256SUMS.txt`: tamanho e SHA-256 de cada arquivo do pacote.

## Arquivo correto para cada finalidade

- **Google Play:** `release/app-release.aab`.
- **Instalação direta/QA:** `qa/app-release.apk`.
- **Ícone da ficha:** `store/pt-BR/graphics/app-icon-512.png`.
- **Ícone instalado:** já está dentro do AAB; os masters ficam em
  `mobile-branding/`.

## Segurança

Este pacote não contém a chave privada JKS, senhas ou propriedades de
assinatura. Nunca envie esses dados à Play Console, ao GitHub ou por e-mail. O
certificado PEM incluído é público e serve para conferência da upload key. O
assunto desse certificado ainda usa o nome técnico histórico `LexiNexo Upload`;
isso não altera a marca pública Worde, o package ou a assinatura.

O arquivo `upload-key-fingerprints.txt` também é um registro público para
auditoria. Ele menciona o SHA-256 da JKS, mas não contém a JKS, senha ou material
capaz de reconstruir a chave privada.

## Status de publicação

O app e os materiais técnicos estão prontos. Publicação efetiva depende da
conta verificada, dos dados públicos verdadeiros do titular, da hospedagem HTTPS
da política/suporte, do questionário IARC, dos termos aceitos e de eventual
teste fechado exigido para contas pessoais novas.

Os únicos dados deliberadamente ausentes estão listados em
`owner-action/PREENCHA_COM_SEUS_DADOS.md`. Eles dependem da identidade real do
titular e não devem ser inventados. Se as páginas finais já tiverem sido
geradas com esses dados, elas estarão em `legal/final/`; caso contrário, use os
templates de `legal/` conforme as instruções daquele documento.

## Nome e marca

O nome público preparado é **Worde: Aprenda Palavras**, mas o kit não constitui
busca ou parecer de marca. Antes do lançamento público, o titular deve pesquisar
o nome no INPI e nas lojas relevantes e, se necessário, consultar um
profissional. A ausência de resultado em uma busca comum, a disponibilidade do
package e a posse de um domínio não garantem o direito sobre a marca.
