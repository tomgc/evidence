---
title: "Attention Is All You Need"
authors:
  - "Vaswani, Ashish"
  - "Shazeer, Noam"
  - "Parmar, Niki"
  - "Uszkoreit, Jakob"
  - "Jones, Llion"
  - "Gomez, Aidan N."
  - "Kaiser, Łukasz"
  - "Polosukhin, Illia"
year: 2017
source: "paper"
journal: "Advances in Neural Information Processing Systems (NeurIPS)"
url: "https://arxiv.org/abs/1706.03762"
doi: "10.48550/arXiv.1706.03762"
tags:
  - deep-learning
  - transformers
  - attention
added_on: 2026-05-17
read: true
abstract: |
  The dominant sequence transduction models are based on complex recurrent or
  convolutional neural networks that include an encoder and a decoder. We propose
  a new simple network architecture, the Transformer, based solely on attention
  mechanisms, dispensing with recurrence and convolutions entirely.
key_findings:
  - "La arquitectura Transformer reemplaza recurrencia y convolución por self-attention puro."
  - "Alcanza estado del arte en traducción automática con significativamente menos cómputo de entrenamiento."
  - "Sienta la base para toda la familia posterior de modelos (BERT, GPT, T5, etc.)."
---

Paper de ejemplo cargado para validar el pipeline.
**Borrar al ingresar el primer paper real de la librería.**

## Notas

Este archivo es un placeholder para ejercitar el parser y demostrar el
rendering de markdown.

### Lo que el cuerpo soporta

- Encabezados de cualquier nivel
- **Negritas**, *cursivas* y `código inline`
- Listas con o sin orden
- [Enlaces externos](https://arxiv.org/abs/1706.03762)
- Bloques de código:

```python
import torch
attention = torch.softmax(Q @ K.T / sqrt(d_k), dim=-1)
output = attention @ V
```

> Citas en bloque, útiles para citar al autor con número de página.

### Pendiente
1. Decidir si vinculo este paper con `bert_2018` y `gpt_2018`.
2. Revisar la sección 3.2 sobre multi-head attention.
