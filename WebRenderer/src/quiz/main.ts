import { listenLinkTaps } from '../core/links'
import { startPage } from '../core/page'
import { type QuizCommand, type QuizMessage, parseQuizCommand } from './commands'
import { QuizRenderer, listenChoiceTaps } from './render'

startPage<QuizCommand, QuizMessage>({
  name: 'quiz',
  parseCommand: parseQuizCommand,
  createRenderer: (root, bridge) => {
    listenLinkTaps((url) => bridge.post({ type: 'linkTapped', url }))
    listenChoiceTaps((id) => bridge.post({ type: 'choiceTapped', id }))
    return new QuizRenderer(root, bridge)
  },
})
