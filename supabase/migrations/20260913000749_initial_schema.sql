-- Tenants
CREATE TABLE tenants (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        VARCHAR(255) NOT NULL,
    slug        VARCHAR(100) UNIQUE NOT NULL,
    plan        VARCHAR(50) NOT NULL DEFAULT 'starter',
    status      VARCHAR(50) NOT NULL DEFAULT 'active',
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- User extended Profile
CREATE TABLE profiles (
    id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    tenant_id   UUID REFERENCES tenants(id),
    email       VARCHAR(255) NOT NULL,
    role        VARCHAR(50) DEFAULT 'owner', -- owner|admin|viewer
    created_at  TIMESTAMPTZ DEFAULT NOW()
);
-- Automatically created upon registration via trigger:
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, email) VALUES (NEW.id, NEW.email);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Connected channels (WhatsApp, IG, FB)
CREATE TABLE channels (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID REFERENCES tenants(id),
    platform        VARCHAR(50) NOT NULL,  -- 'whatsapp'|'instagram'|'facebook'
    platform_id     VARCHAR(255) NOT NULL,
    access_token    TEXT NOT NULL,         -- encriptado con AES-256
    phone_number    VARCHAR(50),
    is_active       BOOLEAN DEFAULT TRUE,
    bot_enabled     BOOLEAN DEFAULT TRUE,
    connected_at    TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, platform)
);

-- Bot configuration per tenant
CREATE TABLE bot_configs (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id            UUID REFERENCES tenants(id) UNIQUE,
    tone                 VARCHAR(50) DEFAULT 'friendly',
    language             VARCHAR(10) DEFAULT 'es-CL',
    handoff_message      TEXT DEFAULT 'Te conecto con nuestro equipo...',
    confidence_threshold DECIMAL(3,2) DEFAULT 0.70,
    business_hours       JSONB,
    out_of_hours_msg     TEXT,
    custom_instructions  TEXT,
    updated_at           TIMESTAMPTZ DEFAULT NOW()
);

-- Product catalog
CREATE TABLE products (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id    UUID REFERENCES tenants(id),
    name         VARCHAR(500) NOT NULL,
    description  TEXT,
    price        INTEGER NOT NULL,  -- en CLP
    stock_status VARCHAR(50) DEFAULT 'available',
    variants     JSONB,
    image_url    TEXT,              -- referencia a Supabase Storage
    is_active    BOOLEAN DEFAULT TRUE,
    created_at   TIMESTAMPTZ DEFAULT NOW(),
    updated_at   TIMESTAMPTZ DEFAULT NOW()
);

-- Product embeddings (for RAG) — native pgvector in Supabase
CREATE EXTENSION IF NOT EXISTS vector;
CREATE TABLE product_embeddings (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id  UUID REFERENCES products(id) ON DELETE CASCADE,
    tenant_id   UUID REFERENCES tenants(id),
    content     TEXT NOT NULL,
    embedding   vector(1536),  -- OpenAI text-embedding-3-small
    created_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX ON product_embeddings USING ivfflat (embedding vector_cosine_ops);

-- Vector search function (callable from the Worker via RPC)
CREATE OR REPLACE FUNCTION search_products(
  query_embedding vector(1536),
  p_tenant_id     uuid,
  match_count     int DEFAULT 3
)
RETURNS TABLE (id uuid, content text, similarity float)
LANGUAGE sql STABLE AS $$
  SELECT id, content, 1 - (embedding <=> query_embedding) AS similarity
  FROM product_embeddings
  WHERE tenant_id = p_tenant_id
  ORDER BY embedding <=> query_embedding
  LIMIT match_count;
$$;

-- Conversations
CREATE TABLE conversations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID REFERENCES tenants(id),
    channel_id      UUID REFERENCES channels(id),
    customer_id     VARCHAR(255) NOT NULL,
    customer_name   VARCHAR(255),
    status          VARCHAR(50) DEFAULT 'bot',
    is_escalated    BOOLEAN DEFAULT FALSE,
    last_message_at TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX ON conversations(tenant_id, last_message_at DESC);

-- Individual messages
CREATE TABLE messages (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID REFERENCES conversations(id),
    tenant_id       UUID REFERENCES tenants(id),
    role            VARCHAR(20) NOT NULL,  -- 'user'|'bot'|'human_agent'
    content         TEXT NOT NULL,
    confidence      DECIMAL(3,2),
    tokens_used     INTEGER,
    was_escalated   BOOLEAN DEFAULT FALSE,
    metadata        JSONB,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX ON messages(conversation_id, created_at);

-- Subscriptions and billing
CREATE TABLE subscriptions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID REFERENCES tenants(id) UNIQUE,
    stripe_customer_id  VARCHAR(255),
    stripe_sub_id       VARCHAR(255),
    plan                VARCHAR(50) NOT NULL,
    status              VARCHAR(50) NOT NULL,
    current_period_end  TIMESTAMPTZ,
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- Daily usage metrics
CREATE TABLE usage_logs (
    tenant_id       UUID REFERENCES tenants(id),
    date            DATE NOT NULL,
    messages_count  INTEGER DEFAULT 0,
    tokens_in       INTEGER DEFAULT 0,
    tokens_out      INTEGER DEFAULT 0,
    escalations     INTEGER DEFAULT 0,
    PRIMARY KEY (tenant_id, date)
);

ALTER TABLE tenants          ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles         ENABLE ROW LEVEL SECURITY;
ALTER TABLE channels         ENABLE ROW LEVEL SECURITY;
ALTER TABLE products         ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations    ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages         ENABLE ROW LEVEL SECURITY;
ALTER TABLE bot_configs      ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_embeddings ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE usage_logs         ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_select_own" ON profiles
  FOR SELECT USING (
    id = auth.uid()
  );

  CREATE POLICY "tenants_select_own" ON tenants
  FOR SELECT USING (
    id = (SELECT tenant_id FROM profiles WHERE id = auth.uid())
  );

CREATE POLICY "tenants_update_own" ON tenants
  FOR UPDATE USING (
    id = (SELECT tenant_id FROM profiles WHERE id = auth.uid())
  );

  CREATE POLICY "tenant_isolation" ON channels
  FOR ALL USING (
    tenant_id = (SELECT tenant_id FROM profiles WHERE id = auth.uid())
  );

CREATE POLICY "tenant_isolation" ON products
  FOR ALL USING (
    tenant_id = (SELECT tenant_id FROM profiles WHERE id = auth.uid())
  );

CREATE POLICY "tenant_isolation" ON conversations
  FOR ALL USING (
    tenant_id = (SELECT tenant_id FROM profiles WHERE id = auth.uid())
  );

CREATE POLICY "tenant_isolation" ON messages
  FOR ALL USING (
    tenant_id = (SELECT tenant_id FROM profiles WHERE id = auth.uid())
  );

CREATE POLICY "tenant_isolation" ON bot_configs
  FOR ALL USING (
    tenant_id = (SELECT tenant_id FROM profiles WHERE id = auth.uid())
  );

CREATE POLICY "tenant_isolation" ON product_embeddings
  FOR ALL USING (
    tenant_id = (SELECT tenant_id FROM profiles WHERE id = auth.uid())
  );

  CREATE POLICY "usage_logs_select_own" ON usage_logs
  FOR SELECT USING (
    tenant_id = (SELECT tenant_id FROM profiles WHERE id = auth.uid())
  );