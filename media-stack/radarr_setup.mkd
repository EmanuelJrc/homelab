# Radarr Setup

# 🎬 **1. Open Radarr**

Go to:

```
http://<your-server-ip>:7878
```

---

# 📁 **2. Set up your root folder**

Radarr needs to know where your movies live.

Because your compose mounts:

```
${MOVIES} → /movies
${MEDIA_ROOT} → /mnt
```

Your **Radarr root folder** is:

```
/movies
```

If you get an error while trying to set it go in terminal and run:

```bash
sudo chown -R 1000:1000 /share_media
```

### Add it:

**Settings → Media Management → Root Folders → Add Root Folder**

Choose:

```
/movies
```

Done.

---

# 📥 **3. Set up your download client (qBittorrent)**

Go to:

**Settings → Download Clients → Add → qBittorrent**

Use:

| Field    | Value                                                      |
| -------- | ---------------------------------------------------------- |
| Host     | `qbittorrent` (because they share the same Docker network) |
| Port     | `8080`                                                     |
| Username | whatever you set                                           |
| Password | whatever you set                                           |
| Category | `radarr` (recommended)                                     |

### Why use category?

Radarr will only touch torrents tagged `radarr`, keeping your client clean.

---

# 📂 **4. Set up your download folder paths**

Your qBittorrent downloads go to:

```
/mnt/downloads
```

Radarr sees the same path because your compose mounts:

```
${MEDIA_ROOT}:/mnt
```

So in Radarr:

**Settings → Download Clients → Remote Path Mappings**

Add:

| Field       | Value            |
| ----------- | ---------------- |
| Host        | `qbittorrent`    |
| Remote Path | `/mnt/downloads` |
| Local Path  | `/mnt/downloads` |

This ensures Radarr can import completed downloads.

---

# 🧠 **5. Configure Media Management**

Go to:

**Settings → Media Management**

Set:

- **Rename Movies** → Yes
- **Standard Movie Format** → your preference
- **Movie Folder Format** → your preference
- **Import Extra Files** → Yes (optional)
- **Delete Empty Folders** → Yes

---

# 🔍 **6. Configure Indexers (via Prowlarr)**

Since you’re using Prowlarr:

1. Open Prowlarr
2. Add your indexers
3. Go to **Settings → Apps**
4. Add Radarr
5. Sync indexers to Radarr

This keeps everything clean and centralized.

---

# 🧪 **7. Test the setup**

Try adding a movie:

1. Search for a movie
2. Click **Add**
3. Choose **Root Folder → /movies**
4. Click **Add + Search**

Radarr should:

- Send the torrent to qBittorrent
- Download into `/mnt/downloads`
- Import into `/movies`
- Rename it
- Clean up the leftover folder

If all that works, Radarr is fully configured.
