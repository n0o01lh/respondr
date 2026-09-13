export type Platform = 'whatsapp' | 'instagram' | 'facebook' | 'mock'
export type Plan = 'starter' | 'pro' | 'business'
export type ConversationStatus = 'bot' | 'human' | 'closed'
export type StockStatus = 'available' | 'out_of_stock' | 'on_request'
export type BotTone = 'formal' | 'friendly' | 'casual'
export type { Database, Json } from './database'

// ─── Message Queue ────────────────────────────────────────────────────────────

export interface MessageJob {
  tenantId: string
  conversationId: string
  messageId: string
  text: string
  senderId: string
  senderName?: string
  platform: Platform
}

// ─── API responses ────────────────────────────────────────────────────────────

export interface HealthResponse {
  status: 'ok'
  timestamp: string
}
