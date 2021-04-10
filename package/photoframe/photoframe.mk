################################################################################
#
# photoframe
#
################################################################################

PHOTOFRAME_LICENSE = GPL-3.0+

define PHOTOFRAME_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(PHOTOFRAME_PKGDIR)/photoframe.sh $(TARGET_DIR)/usr/bin/photoframe.sh
	$(INSTALL) -D -m 0755 $(PHOTOFRAME_PKGDIR)/usb_share.py $(TARGET_DIR)/usr/bin/usb_share.py
	$(INSTALL) -D -m 0755 $(PHOTOFRAME_PKGDIR)/S78firstboot $(TARGET_DIR)/etc/init.d/S78firstboot
	$(INSTALL) -D -m 0755 $(PHOTOFRAME_PKGDIR)/S79usb_share $(TARGET_DIR)/etc/init.d/S79usb_share
	$(INSTALL) -D -m 0644 $(PHOTOFRAME_PKGDIR)/etc_photoframe/davfs2.conf $(TARGET_DIR)/etc/photoframe/davfs2.conf
	$(INSTALL) -D -m 0600 $(PHOTOFRAME_PKGDIR)/etc_photoframe/photoframe.conf $(TARGET_DIR)/etc/photoframe/photoframe.conf
	$(INSTALL) -D -m 0644 $(PHOTOFRAME_PKGDIR)/images/noimages.png $(TARGET_DIR)/usr/share/photoframe/noimages.png
	$(INSTALL) -D -m 0644 $(PHOTOFRAME_PKGDIR)/images/blackimage.png $(TARGET_DIR)/usr/share/photoframe/blackimage.png
endef


$(eval $(generic-package))
