# Quake 3 Server Using Docker Compose

[![Deployment Verification](https://github.com/heyvaldemar/quake3-server-docker-compose/actions/workflows/00-deployment-verification.yml/badge.svg)](https://github.com/heyvaldemar/quake3-server-docker-compose/actions)

The badge displayed on my repository indicates the status of the deployment verification workflow as executed on the latest commit to the main branch.

**Passing**: This means the most recent commit has successfully passed all deployment checks, confirming that the Docker Compose setup functions correctly as designed.

📙 The complete installation guide is available on my [website](https://www.heyvaldemar.com/install-quake3-server-using-docker-compose/).

🐳 You can find the Docker image on [Docker Hub](https://hub.docker.com/r/heyvaldemar/quake3-server).

❗ Change variables in the `.env` and `server.cfg` to meet your requirements.

💡 Note that the `.env` file and `server.cfg` file should be in the same directory as `quake3-server-docker-compose.yml`.

Deploy Quake 3 Server using Docker Compose:

`docker compose -f quake3-server-docker-compose.yml -p quake3-server up -d`

To connect to your Quake 3 server, enter the server's IP address or domain name into your web browser or directly into the Quake 3 client.

# Quake 3 Server Management

Apply new configuration after a change in the `server.cfg` using the command:

```
QUAKE3_SERVER_CONTAINER=$(docker ps -aqf "name=quake3-server-quake3-server") \
&& docker container restart $QUAKE3_SERVER_CONTAINER
```

# Author

I’m Vladimir Mikhalev, the [Docker Captain](https://www.docker.com/captains/vladimir-mikhalev/), but my friends can call me Valdemar.

🌐 My [website](https://www.heyvaldemar.com/) with detailed IT guides\
🎬 Follow me on [YouTube](https://www.youtube.com/channel/UCf85kQ0u1sYTTTyKVpxrlyQ?sub_confirmation=1)\
🐦 Follow me on [Twitter](https://twitter.com/heyValdemar)\
🎨 Follow me on [Instagram](https://www.instagram.com/heyvaldemar/)\
🧵 Follow me on [Threads](https://www.threads.net/@heyvaldemar)\
🐘 Follow me on [Mastodon](https://mastodon.social/@heyvaldemar)\
🧊 Follow me on [Bluesky](https://bsky.app/profile/heyvaldemar.bsky.social)\
🎸 Follow me on [Facebook](https://www.facebook.com/heyValdemarFB/)\
🎥 Follow me on [TikTok](https://www.tiktok.com/@heyvaldemar)\
💻 Follow me on [LinkedIn](https://www.linkedin.com/in/heyvaldemar/)\
🐈 Follow me on [GitHub](https://github.com/heyvaldemar)

# Communication

👾 Chat with IT pros on [Discord](https://discord.gg/AJQGCCBcqf)\
📧 Reach me at ask@sre.gg

# Give Thanks

💎 Support on [GitHub](https://github.com/sponsors/heyValdemar)\
🏆 Support on [Patreon](https://www.patreon.com/heyValdemar)\
🥤 Support on [BuyMeaCoffee](https://www.buymeacoffee.com/heyValdemar)\
🍪 Support on [Ko-fi](https://ko-fi.com/heyValdemar)\
💖 Support on [PayPal](https://www.paypal.com/paypalme/heyValdemarCOM)
