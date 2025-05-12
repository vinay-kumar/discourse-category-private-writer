# Discourse Category Private Writer

This plugin allows you to make one or more categories **"private-writer" style**:
- Writer groups can only see **their own topics**.
- Admin groups can see **all topics**.
- Staff (site admins, moderators) always see all topics.
- Supports multiple categories with separate configurations.

---

## 🔧 Installation

1. SSH into your Discourse server.
2. Clone this repository inside your plugins folder:
   ```bash
   cd /var/discourse
   git clone https://github.com/vinay-kumar/discourse-category-private-writer.git plugins/discourse-category-private-writer
   ./launcher rebuild app
