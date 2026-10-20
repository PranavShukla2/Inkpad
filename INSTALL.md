# Install Inkpad on your iPad

Inkpad isn't on the App Store, but you can still install it for free. It takes about **15 minutes the first time** and about **one tap a week** after that.

## What you need

- An **iPad** with **iPadOS 17 or later** (Settings → General → About → iPadOS Version)
- A **computer**, Mac or Windows, for the first setup
- A free **Apple ID** (the one you already use on your iPad works)
- A **USB cable** for your iPad

## How it works (30-second version)

Apple only lets apps outside the App Store run if they're "signed" with an Apple ID. A free app called **AltStore** does the signing for you with your own Apple ID. Apps signed this way last **7 days**, and AltStore renews them for you, so Inkpad keeps working.

---

## Step 1: Install AltStore (one time)

AltStore has its own short, up-to-date guide, so follow that:

**👉 [altstore.io](https://altstore.io) → follow the steps for AltStore Classic**

In short:

1. Install **AltServer** on your computer.
2. Plug your iPad into the computer and use AltServer to install **AltStore** on the iPad.
3. On the iPad, trust AltStore: **Settings → General → VPN & Device Management** → tap your Apple ID → **Trust**.
4. If your iPad asks you to turn on **Developer Mode**: **Settings → Privacy & Security → Developer Mode** → turn it on → the iPad restarts → tap **Turn On**.

When the AltStore app opens on your iPad, you're ready.

## Step 2: Download Inkpad

1. On your iPad, open **Safari** and go to:
   **[github.com/PranavShukla2/Inkpad/releases/latest](https://github.com/PranavShukla2/Inkpad/releases/latest)**
2. Under **Assets**, tap **Inkpad.ipa**, then tap **Download**.

The file is saved to the **Files** app, in **Downloads**.

## Step 3: Install it with AltStore

1. Open **AltStore** on your iPad.
2. Go to the **My Apps** tab.
3. Tap **+** in the top-left corner.
4. Pick **Inkpad.ipa** from Downloads.
5. If asked, sign in with your Apple ID.

After a few seconds, **Inkpad** appears on your Home Screen. 🎉

## Step 4: Keep it working

Inkpad needs to be **renewed every 7 days**.

- **Automatic:** keep **AltServer running** on your computer, with your iPad on the **same Wi-Fi**. AltStore renews in the background.
- **By hand:** open **AltStore → My Apps → Refresh All**. Your computer still needs to be on with AltServer running.

AltStore shows how many days are left next to Inkpad.

---

## Questions

**Will I lose my notes when it expires or when I refresh?**
No. Your notes stay on your iPad. If Inkpad expires, it just won't open until you refresh it in AltStore. **Don't delete the app**, though: deleting it deletes your notes.

**How do I update to a new version?**
Download the new **Inkpad.ipa** from the same link and install it from AltStore's **+** button again. Your notes are kept.

**It says "Untrusted Developer".**
Go to **Settings → General → VPN & Device Management**, tap your Apple ID and tap **Trust**.

**It says it can't install because of an app limit.**
A free Apple ID can have **3 apps** installed this way at a time, and AltStore counts as one. Remove one you don't use from AltStore's **My Apps** tab.

**I don't want to keep a computer around. Is there another way?**
- **SideStore** ([sidestore.io](https://sidestore.io)) works like AltStore, but after setup it can renew apps without a computer.
- **Sideloadly** ([sideloadly.io](https://sideloadly.io)) is a simple Mac/Windows app: plug in your iPad, drag in **Inkpad.ipa**, enter your Apple ID, press **Start**. You'll need to redo this every 7 days.

**Is it safe to use my Apple ID?**
AltStore, SideStore and Sideloadly only use it to ask Apple to sign the app. Inkpad itself never sees it, doesn't need an account, and keeps everything on your iPad.

**Does it work on iPhone?**
No. Inkpad is designed for iPad and Apple Pencil.

---

Something not working? [Open an issue](https://github.com/PranavShukla2/Inkpad/issues) or message the person who sent you this link.
