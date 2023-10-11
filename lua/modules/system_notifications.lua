--
-- system_notifications module
--

notifications = {}

notifications.available = function(_)
	return System.RemoteNotifAvailable
end

notifications.shouldShowExplanation = function(self)
	-- TODO: gaetan: add finer condition testing here
	return self:available() == false
end

-- high level function to request remote notifications grant
notifications.request = function(self, showInformationPopupFunc)
	if self:available() then
		return -- do nothing
	end

	local infoPopupYes = function(_)
		System:RemoteNotifRequestAccess()
	end

	local infoPopupLater = function(_)
		System:RemoteNotifInfoPopupLater()
	end

	if System.RemoteNotifShouldShowInfoPopup == true then
		showInformationPopupFunc(infoPopupYes, infoPopupLater)
	else
		infoPopupYes()
	end
end

return notifications