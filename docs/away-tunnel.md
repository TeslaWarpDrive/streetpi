# Away from home

At home, the phone talks to the Pi on the house network. That address is 192.168.1.78. The ad blocker answers on the secure port, the charts answer on port 19999, and the status page answers on port 3001.

Away from home, the phone uses https://pistats.thestreetfam.com instead. That name was already published through the Pi's Cloudflare Tunnel, the one called pi-grok-stats. Cloudflare Access checks a service token before a request is allowed through. On the Pi, the tunnel hands the request to a small gate at 127.0.0.1 port 8447. That is the address the tunnel uses. The gate accepts the public name as the Host. It forwards a short list of paths to the ad blocker, the charts, and the status page, and it refuses everything else. The status page slug stays house. A later change keeps it at house when the phone is away.

Brandy does not set this up. There is nothing to turn on, no extra app to install, and no VPN profile to add.

Proton VPN can stay on. The phone is calling a normal public website name, not the house's private address, so the VPN does not have to be off.

The token that opens the gate lives in the phone's keychain. It is not written in this note and it is not in the git repository. If that token leaks, or you think it might have, say so. It gets rotated in Cloudflare Access, the phone gets the new one, and the old one stops working. Do not paste the token into chat, email, or a screenshot.

Keep the decrypted IPA private. A sideload file that has been unlocked can hold a copy of a token. Do not send that file to anyone. Do not put it in a shared drive. Leave the encrypted download encrypted until it is on the phone's computer, and delete the opened file when you are done.
