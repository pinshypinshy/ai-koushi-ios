// Swift との型の食い違いはコンパイラでは見つからないため、届いた値をここの関数で検査し、合わなければ CommandError にする

export class CommandError extends Error {
  override name = 'CommandError'
}

export function record(value: unknown, name: string): Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new CommandError(`${name} がオブジェクトではない`)
  }
  return value as Record<string, unknown>
}

export function array(object: Record<string, unknown>, key: string): unknown[] {
  const value = object[key]
  if (!Array.isArray(value)) throw new CommandError(`${key} が配列ではない`)
  return value
}

export function string(object: Record<string, unknown>, key: string): string {
  const value = object[key]
  if (typeof value !== 'string') throw new CommandError(`${key} が文字列ではない`)
  return value
}

export function nullableString(object: Record<string, unknown>, key: string): string | null {
  const value = object[key]
  if (value === null) return null
  if (typeof value !== 'string') throw new CommandError(`${key} が文字列でも null でもない`)
  return value
}

export function number(object: Record<string, unknown>, key: string): number {
  const value = object[key]
  if (typeof value !== 'number' || !Number.isFinite(value)) throw new CommandError(`${key} が数ではない`)
  return value
}

export function boolean(object: Record<string, unknown>, key: string): boolean {
  const value = object[key]
  if (typeof value !== 'boolean') throw new CommandError(`${key} が真偽値ではない`)
  return value
}

export function assertNever(value: never): never {
  throw new Error(`想定していない値：${JSON.stringify(value)}`)
}
