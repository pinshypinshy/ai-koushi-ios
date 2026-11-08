// Swift の QuizCommand・QuizContent・QuizMessage と対になる
import { CommandError, array, nullableString, record, string } from '../core/validate'

export type ChoiceMark = 'normal' | 'selected' | 'correct' | 'yourAnswer'

export interface QuizChoice {
  readonly id: string
  readonly label: string
  readonly markdown: string
  readonly mark: ChoiceMark
  readonly badge: string | null
}

export interface QuizExplanation {
  readonly heading: string
  readonly markdown: string
  readonly relatedSteps: string
}

export type QuizContent =
  | {
      readonly kind: 'question'
      readonly questionId: string
      readonly stem: string
      readonly choices: readonly QuizChoice[]
      readonly explanation: QuizExplanation | null
    }
  | { readonly kind: 'result'; readonly wrongStems: readonly string[] }

export type QuizScroll = 'top' | 'explanation' | 'keep'

export type QuizCommand = { readonly type: 'render'; readonly content: QuizContent; readonly scroll: QuizScroll }

export type QuizMessage =
  | { readonly type: 'choiceTapped'; readonly id: string }
  | { readonly type: 'linkTapped'; readonly url: string }

export function parseQuizCommand(object: Record<string, unknown>, type: string): QuizCommand {
  switch (type) {
    case 'render':
      return { type, content: parseContent(object['content']), scroll: parseScroll(object) }
    default:
      throw new CommandError(`知らない命令：${type}`)
  }
}

function parseContent(value: unknown): QuizContent {
  const object = record(value, 'content')
  const kind = string(object, 'kind')
  switch (kind) {
    case 'question':
      return {
        kind,
        questionId: string(object, 'questionId'),
        stem: string(object, 'stem'),
        choices: array(object, 'choices').map(parseChoice),
        explanation: object['explanation'] === null ? null : parseExplanation(object['explanation']),
      }
    case 'result':
      return {
        kind,
        wrongStems: array(object, 'wrongStems').map((stem) => {
          if (typeof stem !== 'string') throw new CommandError('wrongStems の要素が文字列ではない')
          return stem
        }),
      }
    default:
      throw new CommandError(`知らない内容の種類：${kind}`)
  }
}

function parseChoice(value: unknown): QuizChoice {
  const object = record(value, '選択肢')
  return {
    id: string(object, 'id'),
    label: string(object, 'label'),
    markdown: string(object, 'markdown'),
    mark: parseMark(object),
    badge: nullableString(object, 'badge'),
  }
}

function parseMark(object: Record<string, unknown>): ChoiceMark {
  const mark = string(object, 'mark')
  switch (mark) {
    case 'normal':
    case 'selected':
    case 'correct':
    case 'yourAnswer':
      return mark
    default:
      throw new CommandError(`知らない印：${mark}`)
  }
}

function parseExplanation(value: unknown): QuizExplanation {
  const object = record(value, 'explanation')
  return {
    heading: string(object, 'heading'),
    markdown: string(object, 'markdown'),
    relatedSteps: string(object, 'relatedSteps'),
  }
}

function parseScroll(object: Record<string, unknown>): QuizScroll {
  const scroll = string(object, 'scroll')
  switch (scroll) {
    case 'top':
    case 'explanation':
    case 'keep':
      return scroll
    default:
      throw new CommandError(`知らないスクロール：${scroll}`)
  }
}
