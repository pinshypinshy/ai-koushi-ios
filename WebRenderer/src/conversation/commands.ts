// Swift の ConversationCommand・ConversationMessage と対になる
import { CommandError, array, boolean, nullableString, record, string } from '../core/validate'

export type ConversationItem =
  | { readonly type: 'divider'; readonly id: string; readonly label: string }
  | { readonly type: 'assistant'; readonly id: string; readonly markdown: string }
  | { readonly type: 'user'; readonly id: string; readonly text: string }
  | { readonly type: 'notice'; readonly id: string; readonly text: string }

export type ConversationCommand =
  | {
      readonly type: 'reset'
      readonly items: readonly ConversationItem[]
      readonly streaming: string | null
      readonly waitingText: string
      readonly scrollToEnd: boolean
    }
  | { readonly type: 'append'; readonly items: readonly ConversationItem[]; readonly scrollToEnd: boolean }
  | { readonly type: 'setStreaming'; readonly text: string | null }

export type ConversationMessage = { readonly type: 'linkTapped'; readonly url: string }

export function parseConversationCommand(object: Record<string, unknown>, type: string): ConversationCommand {
  switch (type) {
    case 'reset':
      return {
        type,
        items: items(object),
        streaming: nullableString(object, 'streaming'),
        waitingText: string(object, 'waitingText'),
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

function items(object: Record<string, unknown>): ConversationItem[] {
  return array(object, 'items').map(parseItem)
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
    case 'notice':
      return { type, id, text: string(object, 'text') }
    default:
      throw new CommandError(`知らない発言の種類：${type}`)
  }
}
