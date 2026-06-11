import org.springframework.web.bind.annotation.GetMapping;

public class AppController {
    @GetMapping("/orders/{id}")
    public String orderById() {
        return "ok";
    }

    public String note() {
        return "/orders/example";
    }
}
