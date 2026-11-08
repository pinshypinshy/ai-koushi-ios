import { listenLinkTaps } from '../core/links'
import { startPage } from '../core/page'
import { type ConversationCommand, type ConversationMessage, parseConversationCommand } from './commands'
import { ConversationRenderer } from './render'

startPage<ConversationCommand, ConversationMessage>({
  name: 'conversation',
  parseCommand: parseConversationCommand,
  createRenderer: (root, bridge) => {
    listenLinkTaps((url) => bridge.post({ type: 'linkTapped', url }))
    return new ConversationRenderer(root, bridge)
  },
})
