int factorial(int num);
void exit();

void main(){
    int ans = factorial(10);
    exit();
}
int factorial(int num){
    if(num <= 1) return 1;
    else return num * factorial(num - 1);
}
void exit(){
    while(1)
    __asm__ __volatile__("csrwi 0x780, 1");
}
