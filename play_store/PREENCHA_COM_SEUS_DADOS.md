# Dados do titular ainda necessários

O código e o kit de preparação do Worde estão organizados. O AAB e o APK finais
com anúncios ainda precisam ser reconstruídos depois que os IDs reais do AdMob
forem fornecidos. A Google também exige que os dados abaixo sejam verdadeiros e
correspondam ao titular da conta. Eles não podem ser inventados por uma
ferramenta ou desenvolvedor.

No pacote extraído, copie
`owner-action/publication_metadata.template.json` para
`owner-action/publication_metadata.json`. No repositório-fonte, use os caminhos
`play_store/publication_metadata.template.json` e
`play_store/publication_metadata.json`. O arquivo usa `schemaVersion: 2` e deve
ser preenchido sem alterar as chaves:

- `developerDisplayName`: nome público que aparecerá na Google Play;
- `accountType`: `personal` ou `organization`, conforme a conta real;
- `supportContactEmail`: e-mail público e monitorado de suporte;
- `privacyContactEmail`: e-mail monitorado para privacidade;
- `developerWebsiteUrl`: site HTTPS público do desenvolvedor ou do app;
- `supportPageUrl`: endereço HTTPS onde a página de suporte será hospedada;
- `privacyPolicyUrl`: endereço HTTPS onde a política será hospedada;
- `supportPhone`: telefone público em formato internacional, ou `null` se não
  quiser exibi-lo;
- `primaryLocale`: mantenha `pt-BR`;
- `distributionCountries`: mantenha `["BR"]` para o lançamento inicial;
- `targetAudience`: mantenha `13+`.

`supportPhone` é somente o telefone público opcional de suporte desta ficha.
Ele não substitui o telefone privado verificado da conta nem o telefone público
de desenvolvedor que a Google possa exigir de uma organização.

## Dados da conta que não pertencem ao JSON

Todas as contas precisam manter diretamente na Play Console um e-mail e um
telefone privados de contato com a Google, ambos verificados, além da identidade
legal solicitada. Não grave esses dados privados no repositório ou no pacote.

Para uma conta **pessoal**, confirme na Console:

- nome legal e endereço do titular;
- e-mail e telefone privados de contato com a Google, verificados;
- e-mail público do desenvolvedor e site público HTTPS;
- identidade e, quando aplicável, verificação de um aparelho Android físico.

Para uma conta de **organização**, confirme na Console:

- nome, endereço e identidade legais da organização;
- D‑U‑N‑S válido e correspondente aos dados legais;
- site oficial HTTPS;
- telefone e e-mail da organização;
- telefone e e-mail públicos do desenvolvedor;
- e-mail e telefone privados de contato com a Google, verificados.

Sempre que possível, os e-mails da organização devem usar o mesmo domínio do
site oficial. A Play Console é a fonte final sobre os campos exibidos para o
tipo e o país da conta.

Também conclua diretamente na conta:

- aceite dos termos e acesso à Play Console.

## Dados reais do AdMob

Crie o app Android `worde.com` na conta real do AdMob e forneça ao ambiente de
build:

- `WORDE_ADMOB_APP_ID`: App ID no formato
  `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`;
- `WORDE_ADMOB_INTERSTITIAL_ID`: unidade intersticial no formato
  `ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY`;
- Publisher ID `pub-XXXXXXXXXXXXXXXX` para publicar o `app-ads.txt` no domínio
  real do desenvolvedor.

Esses valores não podem ser inventados. O build release falha fechado se os
IDs estiverem ausentes, inválidos ou forem os IDs públicos de teste do Google.
Siga todas as etapas de consentimento UMP, frequência, Data Safety e
`app-ads.txt` em `play_store/ADMOB_SETUP.md` no repositório-fonte ou em
`owner-action/ADMOB_SETUP.md` no pacote extraído.

Até os dois IDs reais e o Publisher ID existirem, qualquer APK debug usa
unidades oficiais de teste e serve apenas para desenvolvimento; ele não é um
artefato de publicação nem gera receita.

## Gerar as páginas públicas

Se estiver no **repositório-fonte**, execute:

```powershell
& .\play_store\prepare_publication.ps1
& .\play_store\build_submission_package.ps1
```

O primeiro comando gera as páginas finais de privacidade e suporte com seus
dados em `play_store/generated_publication/`. O segundo monta uma pasta e ZIP
final sem incluir JKS ou senhas.

Se estiver apenas com o **pacote extraído**, substitua os marcadores dos quatro
arquivos `legal/*.template.*` pelos mesmos valores do JSON, preserve uma cópia
preenchida em `legal/final/` e hospede os dois HTML exatamente nas URLs
declaradas. As páginas precisam ser HTTPS, públicas, acessíveis sem login e
corresponder ao titular real.

## Conferir a marca antes do lançamento

Pesquise **Worde** no INPI e nas lojas onde o app será oferecido. Essa busca
é responsabilidade do titular e não está substituída pela disponibilidade de
`worde.com`, do nome na Play Console ou de um domínio. Em caso de dúvida,
obtenha orientação profissional antes da produção.
