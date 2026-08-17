# EMBER Security Setup

## 🔐 Environment Variables Configuration

This project uses environment variables to protect sensitive credentials. **Never commit your `.env` file to version control.**

### First-Time Setup

1. **Copy the example environment file:**
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` and add your Supabase credentials:**
   ```
   SUPABASE_URL=your_supabase_project_url
   SUPABASE_ANON_KEY=your_supabase_anon_key
   ```

3. **Get your credentials from Supabase Dashboard:**
   - Login to [Supabase Dashboard](https://supabase.com/dashboard)
   - Select your project
   - Go to Settings → API
   - Copy the Project URL and anon/public key

### Security Checklist ✅

- [x] `.env` file created locally
- [x] `.env` added to `.gitignore`
- [x] `.env.example` committed (without real credentials)
- [x] `flutter_dotenv` package installed
- [x] Credentials loaded from environment in code

### Important Notes

⚠️ **Never:**
- Commit `.env` to version control
- Share your `.env` file publicly
- Hardcode credentials in source code
- Push sensitive keys to GitHub

✅ **Always:**
- Use `.env.example` as a template
- Keep `.env` local only
- Rotate keys if accidentally exposed
- Use environment variables for secrets

### Files Excluded from Git

The following sensitive files are automatically ignored:
- `.env` and all `.env.*` variants (except `.env.example`)
- `google-services.json` (Android Firebase)
- `GoogleService-Info.plist` (iOS Firebase)
- `service-account*.json` (Service account keys)
- All other credential files

### What to Do If You Accidentally Commit Secrets

1. **Immediately rotate/regenerate** the exposed credentials
2. **Remove from Git history:**
   ```bash
   git filter-branch --force --index-filter \
     "git rm --cached --ignore-unmatch .env" \
     --prune-empty --tag-name-filter cat -- --all
   ```
3. **Force push** (⚠️ only if you're the sole contributor):
   ```bash
   git push origin --force --all
   ```

## 🚀 Deployment

When deploying to production:
1. Set environment variables on your hosting platform
2. Never use the same keys for dev/staging/production
3. Enable Row Level Security (RLS) on all Supabase tables
4. Regularly audit API key usage

---

**Repository Status:** This repository is configured to keep all sensitive data secure. Safe to push to public GitHub ✅
