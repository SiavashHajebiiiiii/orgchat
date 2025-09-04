from django.conf import settings
from django.db import models

User = settings.AUTH_USER_MODEL


class Conversation(models.Model):
    name = models.CharField(max_length=200, blank=True, default="")
    is_group = models.BooleanField(default=False)
    members = models.ManyToManyField(User, related_name="conversations", blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        base = self.name or f"Conversation {self.pk}"
        return f"{base} ({'group' if self.is_group else 'dm'})"


class Message(models.Model):
    conversation = models.ForeignKey(
        Conversation, on_delete=models.CASCADE, related_name="messages"
    )
    sender = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name="sent_messages"
    )
    text = models.TextField(blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["id"]
        indexes = [
            models.Index(fields=["conversation", "created_at"]),
            models.Index(fields=["conversation", "id"], name="chat_msg_conv_id_idx"),
        ]

    def __str__(self):
        return f"Msg#{self.pk} by {self.sender_id} in Conv#{self.conversation_id}"


class MessageAttachment(models.Model):
    message = models.ForeignKey(
        Message, related_name="attachments", on_delete=models.CASCADE
    )
    file = models.FileField(upload_to="attachments/%Y/%m/%d")
    content_type = models.CharField(max_length=100, blank=True, default="")  # ← 100
    size = models.IntegerField(default=0)                                    # ← integer
    uploaded_at = models.DateTimeField(auto_now_add=True)                    # ← نام درست

    class Meta:
        ordering = ["id"]

    def __str__(self):
        return f"Attachment#{self.pk} of Msg#{self.message_id}"
