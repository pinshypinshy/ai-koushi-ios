// Swift の Theme と対になる
import { number, record, string } from './validate'

export const colorNames = [
  'text',
  'secondaryText',
  'link',
  'error',
  'border',
  'userMessageBackground',
  'userMessageText',
  'codeBackground',
  'codeBlockBackground',
  'codeBlockText',
  'tableHeaderBackground',
  'choiceBackground',
  'choiceBorder',
  'choiceSelected',
  'answerCorrect',
  'answerIncorrect',
] as const

export type ColorName = (typeof colorNames)[number]

export interface Theme {
  readonly colors: Readonly<Record<ColorName, string>>
  readonly fontSize: number
}

export function parseTheme(value: unknown): Theme {
  const object = record(value, 'theme')
  const colorsObject = record(object['colors'], 'colors')
  const colors = Object.fromEntries(colorNames.map((name) => [name, string(colorsObject, name)]))
  return {
    colors: colors as Record<ColorName, string>,
    fontSize: number(object, 'fontSize'),
  }
}

export function applyTheme(theme: Theme): void {
  const style = document.documentElement.style
  for (const name of colorNames) style.setProperty(`--color-${name}`, theme.colors[name])
  style.setProperty('--font-size', `${theme.fontSize}px`)
}
