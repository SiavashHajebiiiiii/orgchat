from django.urls import path
from .views import ConversationListCreateView, MessageListView, MessageSendView

urlpatterns = [
    # GET = لیست گفتگوها، POST = ساخت DM/گروه
    path("conversations/", ConversationListCreateView.as_view(), name="conversation-list-create"),

    # GET پیام‌های یک گفتگو
    path("messages/<int:conversation_id>/", MessageListView.as_view(), name="message-list"),

    # POST ارسال پیام
    path("messages/send/", MessageSendView.as_view(), name="message-send"),
]
