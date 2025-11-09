CREATE TABLE IF NOT EXISTS notification (
                                     id UUID PRIMARY KEY,
                                     message_header TEXT,
                                     message_body TEXT,
                                     notification_type TEXT CHECK (notification_type IN ('info', 'action')),
                                     notification_status TEXT CHECK (notification_status IN ('read', 'unread')),
    notification_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

ALTER TABLE users ADD COLUMN auth0_user_id VARCHAR(200);