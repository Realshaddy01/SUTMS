from allauth.account.adapter import DefaultAccountAdapter
from django.conf import settings


class CustomAccountAdapter(DefaultAccountAdapter):
    def save_user(self, request, user, form, commit=True):
        """
        Override save_user to handle custom fields from registration form
        """
        user = super().save_user(request, user, form, commit=False)
        
        # Process data from the form
        data = form.cleaned_data
        user.full_name = data.get('full_name', '')
        user.phone_number = data.get('phone_number', '')
        
        if commit:
            user.save()
            
        return user