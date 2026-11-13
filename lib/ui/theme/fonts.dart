// Fontes embutidas no app (declaradas no pubspec.yaml, em assets/fonts/).
// Para adicionar uma: coloque o .ttf, declare no pubspec e inclua aqui.

// Inter é a mais parecida com a SF Pro do Mac (que não pode ser distribuída).
const uiFonts = [
  'Inter',
  'Geist',
  'Figtree',
  'Manrope',
  'Plus Jakarta Sans',
  'Onest',
  'DM Sans',
  'Nunito',
  'IBM Plex Sans',
  'Atkinson Hyperlegible',
];
const handFonts = [
  'Caveat',
  'Excalifont', // a do Excalidraw
  'Virgil', // a antiga do Excalidraw
  'Shantell Sans',
  'Shadows Into Light',
  'Coming Soon',
  'Nanum Pen Script',
  'Gaegu',
  'Kalam',
  'Patrick Hand',
  'Gochi Hand',
  'Indie Flower',
  'Architects Daughter',
  'Sue Ellen Francisco',
];
const monoFonts = [
  'JetBrains Mono',
  'IBM Plex Mono',
  'Geist Mono',
  'DM Mono',
  'Fira Code',
  'Victor Mono',
  'Courier Prime',
  'Space Mono',
];

/// Os números podem usar as fontes de máquina ou as mesmas letras de mão.
const numberFonts = [...monoFonts, ...handFonts];

const defaultUiFont = 'Inter';
const defaultHandFont = 'Caveat';
const defaultMonoFont = 'JetBrains Mono';

/// Cada letra de mão tem um "tamanho visual" diferente; isto equaliza.
double handScale(String family) => switch (family) {
  'Caveat' => 1.18,
  'Indie Flower' => 0.95,
  'Gochi Hand' => 1.02,
  'Architects Daughter' => 0.86,
  'Sue Ellen Francisco' => 1.1,
  'Excalifont' => 0.94,
  'Virgil' => 0.94,
  'Shantell Sans' => 0.86,
  'Shadows Into Light' => 0.9,
  'Coming Soon' => 0.8,
  'Nanum Pen Script' => 1.28,
  'Gaegu' => 1.12,
  _ => 1.0,
};

/// Tamanhos do texto (Ajustes → Aparência).
const textScales = [(0.9, 'Pequeno'), (1.0, 'Normal'), (1.1, 'Grande'), (1.2, 'Maior')];
