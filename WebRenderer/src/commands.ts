// Swift の ConversationCommand と対になる。
// 型の食い違いはコンパイラでは見つからないため、届いた値をここで検査し、合わなければ CommandError にする

export type ConversationItem =
  | { readonly type: 'divider'; readonly id: string; readonly label: string }
  | { readonly type: 'assistant'; readonly id: string; readonly markdown: string }
  | { readonly type: 'user'; readonly id: string; readonly text: string }

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
] as const

export type ColorName = (typeof colorNames)[number]

export interface Configuration {
  readonly colors: Readonly<Record<ColorName, string>>
  readonly fontSize: number
  readonly waitingText: string
}

export type Command =
  | { readonly type: 'configure'; readonly configuration: Configuration }
  | {
      readonly type: 'reset'
      readonly items: readonly ConversationItem[]
      readonly streaming: string | null
      readonly scrollToEnd: boolean
    }
  | { readonly type: 'append'; readonly items: readonly ConversationItem[]; readonly scrollToEnd: boolean }
  | { readonly type: 'setStreaming'; readonly text: string | null }

export class CommandError extends Error {
  override name = 'CommandError'
}

export function parseCommands(json: string): Command[] {
  const value: unknown = JSON.parse(json)
  if (!Array.isArray(value)) throw new CommandError('命令が配列ではない')
  return value.map(parseCommand)
}

function parseCommand(value: unknown): Command {
  const object = record(value, '命令')
  const type = string(object, 'type')
  switch (type) {
    case 'configure':
      return { type, configuration: parseConfiguration(object['configuration']) }
    case 'reset':
      return {
        type,
        items: items(object),
        streaming: nullableString(object, 'streaming'),
        scrollToEnd: boolean(object, 'scrollToEnd'),
      }
    case 'append':
      return { type, items: items(object), scrollToEnd: boolean(object, 'scrollToEnd') }
    case 'setStreaming':
      return { type, text: nullableString(object, 'text') }
    default:
      throw new CommandError(`知らない命令：${type}`)
  }
}

function parseConfiguration(value: unknown): Configuration {
  const object = record(value, 'configuration')
  const colorsObject = record(object['colors'], 'colors')
  const colors = Object.fromEntries(colorNames.map((name) => [name, string(colorsObject, name)]))
  return {
    colors: colors as Record<ColorName, string>,
    fontSize: number(object, 'fontSize'),
    waitingText: string(object, 'waitingText'),
  }
}

function items(object: Record<string, unknown>): ConversationItem[] {
  const value = object['items']
  if (!Array.isArray(value)) throw new CommandError('items が配列ではない')
  return value.map(parseItem)
}

function parseItem(value: unknown): ConversationItem {
  const object = record(value, '発言')
  const type = string(object, 'type')
  const id = string(object, 'id')
  switch (type) {
    case 'divider':
      return { type, id, label: string(object, 'label') }
    case 'assistant':
      return { type, id, markdown: string(object, 'markdown') }
    case 'user':
      return { type, id, text: string(object, 'text') }
    default:
      throw new CommandError(`知らない発言の種類：${type}`)
  }
}

function record(value: unknown, name: string): Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new CommandError(`${name} がオブジェクトではない`)
  }
  return value as Record<string, unknown>
}

function string(object: Record<string, unknown>, key: string): string {
  const value = object[key]
  if (typeof value !== 'string') throw new CommandError(`${key} が文字列ではない`)
  return value
}

function nullableString(object: Record<string, unknown>, key: string): string | null {
  const value = object[key]
  if (value === null) return null
  if (typeof value !== 'string') throw new CommandError(`${key} が文字列でも null でもない`)
  return value
}

function number(object: Record<string, unknown>, key: string): number {
  const value = object[key]
  if (typeof value !== 'number' || !Number.isFinite(value)) throw new CommandError(`${key} が数ではない`)
  return value
}

function boolean(object: Record<string, unknown>, key: string): boolean {
  const value = object[key]
  if (typeof value !== 'boolean') throw new CommandError(`${key} が真偽値ではない`)
  return value
}
