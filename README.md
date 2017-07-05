# Danielle Church's Portage overlay

This is a [Portage overlay][overlay] with ebuilds that I have created
or modified.


## Install

1. Make sure you have [layman][layman] installed.
2. Run `sudo layman -f -o https://raw.githubusercontent.com/dmchurch/portage-overlay/master/repositories.xml -a dmchurch`.
3. You can now emerge packages from the overlay. Example: `sudo emerge slack-chat`.

## Packages provided

* `app-crypt/keybase`
* `app-crypt/keybase-bin`
* `net-im/slack-chat`

[overlay]: https://wiki.gentoo.org/wiki/Overlay
[layman]: http://wiki.gentoo.org/wiki/Layman
