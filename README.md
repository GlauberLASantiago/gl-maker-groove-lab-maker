# GL Maker: Groove Lab Maker

Editor visual em HTML para criar, editar e exportar levadas musicais para um plugin do MuseScore.

O app gera automaticamente o plugin **GL: Groove Lab**, que permite criar acordes e aplicar levadas/viradas diretamente em partituras do MuseScore.

<img width="1239" height="760" alt="image" src="https://github.com/user-attachments/assets/5308cb68-6a4f-4842-8fcb-225726e63ffb" />

<img width="1261" height="607" alt="image" src="https://github.com/user-attachments/assets/bc612225-311c-471e-bbd6-077c8cc5a93f" />


## Visão geral

**GL Maker: Groove Lab Maker** é uma ferramenta em arquivo único HTML criada para facilitar a edição de padrões rítmicos, chamados aqui de **levadas** e **viradas**.

Com ele, é possível montar padrões de 1 ou 2 compassos usando eventos de:

* **Acorde**
* **Pausa**

Depois de editar as levadas, o app exporta um arquivo `.qml` completo para uso como plugin no MuseScore.

O plugin gerado se chama:

**GL: Groove Lab**

## Principais recursos

* Editor visual de levadas em HTML, sem necessidade de instalação.
* Criação de levadas de **1 ou 2 compassos**.
* Inserção de eventos de **acorde** e **pausa**.
* Validação visual da duração total da levada.
* Duplicação, exclusão, edição e reordenação das levadas com o mouse (**Drag & Drop**).
* Exportação automática do plugin `.qml` para MuseScore.
* Geração de acordes a partir de uma nota selecionada.
* Aplicação de levadas sobre acordes já escritos.
* Suporte experimental para aplicar levadas a partir de cifras/harmonias selecionadas no MuseScore.
* Auto voicing opcional para reorganizar notas na região **G3–B4**.

## Arquivos do projeto

O projeto pode ser organizado assim:

```text
.
├── index.html
├── README.md
└── exemplos/
    └── GL - Groove Lab.qml
```

### `index.html`

Arquivo único do app **GL Maker: Groove Lab Maker**.

Abra este arquivo no navegador para editar levadas e gerar o plugin MuseScore.

### `GL - Groove Lab.qml`

Arquivo gerado pelo app HTML.

Este é o plugin que deve ser instalado no MuseScore.

## Como usar o editor HTML

1. Abra o arquivo `index.html` em um navegador moderno.
2. Escolha uma levada existente ou clique em **Nova levada**.
3. Defina se a levada terá **1** ou **2 compassos**.
4. Adicione eventos de **Acorde** ou **Pausa**.
5. Ajuste as durações até a levada fechar corretamente.
6. Clique em **Baixar plugin .qml**.
7. O arquivo exportado será chamado:

```text
GL - Groove Lab.qml
```

## Como instalar o plugin no MuseScore

1. Abra o MuseScore.
2. Vá até a pasta de plugins do MuseScore.
3. Copie o arquivo gerado:

```text
GL - Groove Lab.qml
```

4. Reinicie o MuseScore ou recarregue os plugins.
5. Ative o plugin no gerenciador de plugins, se necessário.
6. O plugin aparecerá no menu:

```text
Plugins > GL: Groove Lab
```

## Como usar o plugin GL: Groove Lab

### Criar acordes

1. Selecione uma cabeça de nota na partitura.
2. No plugin, informe se a nota selecionada representa:

   * Fundamental
   * Terça
   * Quinta
   * Sétima
3. Clique no tipo de acorde desejado, por exemplo:

   * `X`
   * `Xm`
   * `Xmaj7`
   * `X7`
   * `Xm7`
   * `Xm7(b5)`
   * `Xdim7`

O plugin adicionará as demais notas ao acorde respeitando a grafia musical/enarmonia.

### Aplicar levadas a partir de uma nota ou acorde

1. Selecione uma nota de um acorde já escrito.
2. Clique em uma das levadas ou viradas disponíveis.
3. O plugin repetirá o acorde conforme o padrão rítmico escolhido.

### Aplicar levadas a partir de cifra

O plugin também possui suporte experimental para aplicar levadas a partir de cifras/harmonias do MuseScore.

Exemplos de cifras reconhecidas:

* `C`
* `Cm`
* `C7`
* `Cmaj7`
* `Cm7`
* `Cm7b5`
* `Cdim`
* `Cdim7`
* `Csus4`
* `Cadd9`

Fluxo sugerido:

1. Insira uma cifra no MuseScore.
2. Selecione ou clique na cifra.
3. Abra o plugin **GL: Groove Lab**.
4. Clique em uma levada.

O plugin tentará interpretar a cifra e gerar as notas correspondentes para aplicar a levada.

> Observação: o comportamento de seleção de cifras pode variar entre versões do MuseScore. Em alguns casos, pode ser necessário selecionar também o ponto rítmico associado à cifra.

## Auto voicing

O botão **Auto voicing** reorganiza notas por oitavas para tentar manter o acorde dentro da região:

```text
G3–B4
```

Isso pode ajudar a manter as levadas em uma região mais prática para acompanhamento harmônico.

## Personalização das levadas

As levadas são editadas no HTML, não diretamente no plugin.

O fluxo recomendado é:

1. Editar levadas no **GL Maker: Groove Lab Maker**.
2. Exportar novamente o arquivo `.qml`.
3. Substituir o plugin antigo no MuseScore.
4. Recarregar/reiniciar o MuseScore.

## Tecnologias utilizadas

* HTML
* CSS
* JavaScript
* QML
* API de plugins do MuseScore

## Compatibilidade

O plugin foi desenvolvido com base na estrutura de plugins QML do MuseScore.

Importações usadas no plugin gerado:

```qml
import MuseScore 3.0
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
```

## Limitações conhecidas

* A leitura de cifras/harmonias depende de como a versão do MuseScore expõe elementos `HARMONY` e anotações de segmento para plugins.
* Cifras muito complexas, com muitas alterações ou extensões, podem não ser interpretadas completamente.
* O editor HTML valida a duração da levada, mas não substitui uma revisão musical do resultado final.
* O plugin trabalha com padrões rítmicos definidos no momento da exportação; para alterar levadas, gere um novo `.qml`.

## Créditos

Desenvolvido pelo professor **Glauber Santiago** — **DAC/UFSCar**
servidores.ufscar.br/glauber/ • sites.google.com/view/glauberia

No plugin MuseScore gerado, os créditos aparecem como:

```text
Desenvolvido pelo professor Glauber Santiago - UFSCar
```

## Licença

Defina aqui a licença desejada para o projeto.

Sugestões comuns:

* MIT License
* GPL-3.0 License
* Creative Commons BY-SA

Exemplo:

```text
Este projeto é distribuído sob a licença MIT.
```

## Sugestão de descrição curta para o GitHub

```text
Editor HTML para criar levadas e exportar o plugin GL: Groove Lab para MuseScore.
```

## Sugestão de tópicos para o repositório

```text
musescore
qml
music-education
music-theory
harmony
groove
rhythm
plugin
html
javascript
```
